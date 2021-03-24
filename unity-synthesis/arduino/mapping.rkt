#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "bitvector.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match
         ;; unsafe! only allowed for concrete evaluation
         (only-in racket/base string->symbol))

(define max-pin-id
  21)

;; The Arduino model admits four different sorts of mutable references: byte
;; variables, unsigned int variables, input pins, and output pins. Variables are
;; used for internal state, and pins are used for external state (input/output).
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
;; unity_context -> synth_map
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

  ;; (f: symbol -> (fn: arduino_state -> unity_val))
  ;; -> arduino_state
  ;; -> unity_state
  (define (state-mapper state-map state)
    (match state-map
      ['() '()]
      [(cons (cons id fn) tail)
       (cons (cons id (fn state))
             (state-mapper tail state))]))

  ;; (f: symbol -> (fn: arduino_state -> unity_val))
  ;; -> unity_id
  ;; -> arduino_state
  ;; -> unity_val
  (define (state-id-mapper state-map id state)
    (let ([id-fn (get-mapping id state-map)])
      (if (null? id-fn)
          '()
          (id-fn state))))

  (define (target-id-writable? id cxt)
    (match (get-mapping id cxt)
      ['byte #t]
      ['unsigned-int #t]
      ['pin-out #t]
      [_ #f]))

  (define (helper working-unity-cxt arduino-cxt state-map inv-map current-pin)
    (match working-unity-cxt
      ['() (synth-map (unity:context->external-vars unity-context)
                      (unity:context->internal-vars unity-context)
                      arduino-cxt
                      (symbolic-state arduino-cxt)
                      (lambda (id) (target-id-writable? id arduino-cxt))
                      (lambda (st) (state-mapper state-map st))
                      (lambda (id st) (state-id-mapper state-map id st))
                      (lambda (id) (get-mapping id inv-map)))]
      [(cons (cons id 'boolean) tail)
       (helper tail
               (cons (cons id 'unsigned-int)
                     arduino-cxt)
               (cons (cons id
                           (lambda (st)
                             (bitvector->bool (get-mapping id st))))
                     state-map)
               (cons (cons id (list id))
                     inv-map)
               current-pin)]
      [(cons (cons id 'natural) tail)
       (helper tail
               (cons (cons id 'unsigned-int)
                     arduino-cxt)
               (cons (cons id
                           (lambda (st)
                             (bitvector->natural (get-mapping id st))))
                     state-map)
               (cons (cons id (list id))
                     inv-map)
               current-pin)]
      [(cons (cons id 'recv-channel) tail)
       (let* ([req-pin current-pin]
              [ack-pin (next-pin-id req-pin)]
              [val-pin (next-pin-id ack-pin)]
              [req-id (symbol-format "d~a" req-pin)]
              [ack-id (symbol-format "d~a" ack-pin)]
              [val-id (symbol-format "d~a" val-pin)])
         (helper tail
                 (append (list (cons req-id 'pin-in)
                               (cons ack-id 'pin-out)
                               (cons val-id 'pin-in))
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
                 (cons (cons id (list req-id ack-id val-id))
                       inv-map)
                 (next-pin-id val-pin)))]
      [(cons (cons id 'send-channel) tail)
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
                 (cons (cons id (list req-id ack-id val-id))
                       inv-map)
                 (next-pin-id val-pin)))]
      [(cons (cons id 'recv-buf) tail)
       (let ([rcvd-id (symbol-format "~a_rcvd" id)]
             [vals-id (symbol-format "~a_vals" id)])
         (helper tail
                 (append (list (cons rcvd-id 'unsigned-int)
                               (cons vals-id 'unsigned-int))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([rcvd-val (get-mapping rcvd-id st)]
                                     [vals-val (get-mapping vals-id st)])
                                 (unity:buffer* (bitvector->natural rcvd-val)
                                                (map bitvector->bool
                                                     (bitvector->bits vals-val))))))
                       state-map)
                 (cons (cons id (list rcvd-id vals-id))
                       inv-map)
                 current-pin))]
      [(cons (cons id 'send-buf) tail)
       (let ([sent-id (symbol-format "~a_sent" id)]
             [vals-id (symbol-format "~a_vals" id)])
         (helper tail
                 (append (list (cons sent-id 'unsigned-int)
                               (cons vals-id 'unsigned-int))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([sent-val (get-mapping sent-id st)]
                                     [vals-val (get-mapping vals-id st)])
                                 (unity:buffer* (bitvector->natural sent-val)
                                                (map bitvector->bool
                                                     (bitvector->bits vals-val))))))
                       state-map)
                 (cons (cons id (list sent-id vals-id))
                       inv-map)
                 current-pin))]))

  (helper unity-context '() '() '() 0))

(define (unity-prog->synth-map unity-prog)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (unity-context->synth-map unity-cxt)]))

(provide unity-prog->synth-map)
