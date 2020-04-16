#lang rosette/safe

(require "../util.rkt"
         "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         rosette/lib/angelic
         rosette/lib/synthax
         rosette/lib/match
         ;; unsafe! only allowed for concrete evaluation
         (only-in racket/base string->symbol))

(define max-expression-depth
  3)

(define max-statement-depth
  5)

(define max-pin-id
  21)

;; bitvector -> nat -> big endian boolean list
(define (bitvec->be-bool-list len bitvec)
  (define 0x01 (bv 1 8))
  (define 0x80 (bv (expt 2 7) 8))

  (if (<= len 0)
      '()
      (cons (true-byte? (bvand bitvec 0x80))
            (bitvec->be-bool-list (sub1 len)
                                  (bvshl bitvec 0x01)))))

;; bitvector -> nat -> little endian boolean list
(define (bitvec->le-bool-list len bitvec)
  (define 0x01 (bv 1 8))

  (if (<= len 0)
      '()
      (cons (true-byte? (bvand bitvec 0x01))
            (bitvec->le-bool-list (sub1 len)
                                  (bvlshr bitvec 0x01)))))

(define (symbolic-state context)
  (define (symbolic-boolean)
    (define-symbolic* b boolean?)
    b)
  
  (define (symbolic-byte)
    (define-symbolic* b (bitvector 8))
    b)

  (define (helper cxt)
    (match cxt
      ['() '()]
      [(cons (cons id typ) tail)
       (cons (cons id (match typ
                        ['byte (symbolic-byte)]
                        ['pin-in (symbolic-boolean)]
                        ['pin-out (symbolic-boolean)]))
             (helper tail))]))

  (helper context))

(struct synth-map
  (arduino-context
   arduino-state->unity-state)
  #:transparent)

;; The Arduino model admits three different sorts of mutable references: byte
;; variables, input pins, and output pins. Variables are used for internal
;; state, and pins are used for external state (input/output).
;;
;; The current strategy for showing equivalence is to translate a
;; UNITY context C_u into an Arduino context C_a, and to derive a mapping
;; from any Arduino state S_a that satisifes C_a to a UNITY state S_u
;; that satisifies C_u.
;;
;; We can show that two programs are equivalent by generating an Arduino
;; symbolic state S_a that satisifies C_a, mapping it to a symbolic UNITY state
;; S_a->S_u, symbolically interpreting the reference program against S_a->S_u
;; yielding a new symbolic state S_a->S_u', then finding an Arduino program P
;; such that interpreting P against S_a yields a state S_a' such that the
;; mapping into the UNITY state S_a'->S_u' is equivalent to S_a->S_u.
;;
;; This function takes a UNITY context and provides a corresponding synth-map.
;;
;; unity_context ->
;; (synth-map arduino_context, f: arduino_state -> unity_state)
(define (unity-context->synth-map unity-context)
  ;; num -> num (checking to see if we're within pin bounds)
  (define (next-pin-id current)
    (if (>= current max-pin-id)
        current
        (add1 current)))

  ;; create a new symbol according to format
  (define (symbol-format fmt sym)
    (string->symbol (format fmt sym)))

  ;; map: symbol to f: arduino_state -> unity_state ->
  ;; arduino_state ->
  ;; unity_state
  (define (state-mapper state-map state)
    (match state-map
      ['() '()]
      [(cons (cons id fn) tail)
       (cons (cons id (fn state))
             (state-mapper tail state))]))

  (define (helper unity-cxt arduino-cxt state-map current-pin)
    (match unity-cxt
      ['() (synth-map arduino-cxt
                      (lambda (st) (state-mapper state-map st)))]
      [(cons (cons id 'boolean) tail)
       (helper tail
               (cons (cons id 'byte)
                     arduino-cxt)
               (cons (cons id
                           (lambda (st)
                             (true-byte? (get-mapping id st))))
                     state-map)
               current-pin)]
      [(cons (cons id 'natural) tail)
       (helper tail
               (cons (cons id 'byte)
                     arduino-cxt)
               (cons (cons id
                           (lambda (st)
                             (bitvector->natural (get-mapping id st))))
                     state-map)
               current-pin)]
      [(cons (cons id 'channel) tail)
       (let* ([req-pin current-pin]
              [ack-pin (next-pin-id req-pin)]
              [val-pin (next-pin-id ack-pin)]
              [req-id (symbol-format "d~a" req-pin)]
              [ack-id (symbol-format "d~a" ack-pin)]
              [val-id (symbol-format "d~a" val-pin)])
         (helper tail
                 (append (list (cons req-id 'pin-out)
                               (cons ack-id 'pin-in)
                               (cons val-id 'pin-out))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([req-v (get-mapping req-id st)]
                                     [ack-v (get-mapping ack-id st)]
                                     [val-v (get-mapping val-id st)])
                                 (if (xor req-v ack-v)
                                     (unity:channel* #t val-v)
                                     (unity:channel* #f null)))))
                       state-map)
                 val-pin))]
      [(cons (cons id 'send-buf) tail)
       (let ([vals-id (symbol-format "~a_vals" id)]
             [sent-id (symbol-format "~a_sent" id)])
         (helper tail
                 (append (list (cons vals-id 'byte)
                               (cons sent-id 'byte))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([vals-val (get-mapping vals-id st)]
                                     [sent-val (bitvector->natural (get-mapping sent-id st))])
                                 (unity:send-buf* sent-val
                                                  (bitvec->be-bool-list 8 vals-val)))))
                       state-map)
                 current-pin))]
      [(cons (cons id 'recv-buf) tail)
       (let ([vals-id (symbol-format "~a_vals" id)]
             [rcvd-id (symbol-format "~a_rcvd" id)])
         (helper tail
                 (append (list (cons vals-id 'byte)
                               (cons rcvd-id 'byte))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([vals-val (get-mapping vals-id st)]
                                     [rcvd-val (bitvector->natural (get-mapping rcvd-id st))])
                                 (unity:recv-buf* rcvd-val
                                                  (bitvec->le-bool-list 8 vals-val)))))
                       state-map)
                 current-pin))]))

  (helper unity-context '() '() 0))

(provide max-expression-depth
         max-statement-depth
         max-pin-id
         symbolic-state
         synth-map
         synth-map-arduino-context
         synth-map-arduino-state->unity-state
         unity-context->synth-map)
