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

(struct synth-map
  (unity-external-vars
   unity-internal-vars
   arduino-context
   arduino-symbolic-state
   arduino-state->unity-state)
  #:transparent)

(struct synth-traces
  (initially
   assign)
  #:transparent)

(struct guarded-trace
  (guard
   trace)
  #:transparent)

(define max-expression-depth
  5)

(define max-pin-id
  21)

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
  (define (state-mapper state-map state)
    (match state-map
      ['() '()]
      [(cons (cons id fn) tail)
       (cons (cons id (fn state))
             (state-mapper tail state))]))

  (define (helper working-unity-cxt arduino-cxt state-map current-pin)
    (match working-unity-cxt
      ['() (synth-map (unity:context->external-vars unity-context)
                      (unity:context->internal-vars unity-context)
                      arduino-cxt
                      (symbolic-state arduino-cxt)
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
                 (next-pin-id val-pin)))]
      [(cons (cons id 'recv-buf) tail)
       (let ([rcvd-id (symbol-format "~a_rcvd" id)]
             [vals-id (symbol-format "~a_vals" id)])
         (helper tail
                 (append (list (cons rcvd-id 'byte)
                               (cons vals-id 'byte))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([rcvd-val (get-mapping rcvd-id st)]
                                     [vals-val (get-mapping vals-id st)])
                                 (unity:buffer* (bitvector->natural rcvd-val)
                                                (map bitvector->bool
                                                     (bitvector->bits vals-val))))))
                       state-map)
                 current-pin))]
      [(cons (cons id 'send-buf) tail)
       (let ([sent-id (symbol-format "~a_sent" id)]
             [vals-id (symbol-format "~a_vals" id)])
         (helper tail
                 (append (list (cons sent-id 'byte)
                               (cons vals-id 'byte))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([sent-val (get-mapping sent-id st)]
                                     [vals-val (get-mapping vals-id st)])
                                 (unity:buffer* (bitvector->natural sent-val)
                                                (map bitvector->bool
                                                     (bitvector->bits vals-val))))))
                       state-map)
                 current-pin))]))

  (helper unity-context '() '() 0))

(define (unity-prog->synth-map unity-prog)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (unity-context->synth-map unity-cxt)]))

(define (unity-prog->synth-traces unity-prog synthesis-map)
  (define (symbolic-pair->guarded-trace p)
    (let ([guard (car p)]
          [stobj (cdr p)])
      (if (null? stobj)
          '()
          (guarded-trace guard
                         (unity:stobj-state stobj)))))

  (define (stobj->guarded-traces stobj)
    (if (union? stobj)
        (flatten
         (map symbolic-pair->guarded-trace
              (union-contents stobj)))
        (symbolic-pair->guarded-trace (cons #t stobj))))

  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (let* ([ext-vars (synth-map-unity-external-vars synthesis-map)]
            [int-vars (synth-map-unity-internal-vars synthesis-map)]
            [arduino-cxt (synth-map-arduino-context synthesis-map)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]
            [arduino-start-st (synth-map-arduino-symbolic-state synthesis-map)]
            [unity-start-st (arduino-st->unity-st arduino-start-st)]
            [unity-start-stobj (unity:stobj unity-start-st)]
            [unity-start-env (unity:interpret-declare unity-prog unity-start-stobj)]
            [unity-initialized-env (unity:interpret-initially
                                    unity-prog
                                    unity-start-env)]
            [unity-assigned-env (unity:interpret-assign
                                 unity-prog
                                 unity-start-env)])
       (synth-traces (stobj->guarded-traces
                      (unity:environment*-stobj unity-initialized-env))
                     (stobj->guarded-traces
                      (unity:environment*-stobj unity-assigned-env))))]))


;; Ensures a monotonic transition for each key-value
;;
;; For each arduino pre and post state, we generate a inclusive list of
;; intermediate states, project them into UNITY states, and for every key, we
;; ensure that that key transitions from the unity-pre state into the unity-post
;; state and stays there.
(define (monotonic-pre-to-post? keys
                                arduino-pre
                                arduino-post
                                unity-pre
                                unity-post
                                arduino-st->unity-st)

  (define (prefix-states arduino-st)
    (if (eq? arduino-st arduino-pre)
        (list (arduino-st->unity-st arduino-pre))
        (cons (arduino-st->unity-st arduino-st)
              (prefix-states (cdr arduino-st)))))

  (define (key-trace key states pre-val post-val)
    (map (lambda (s)
           (let ([val (get-mapping key s)])
             (cond
               [(eq? val pre-val) 'pre]
               [(eq? val post-val) 'post]
               [else 'fail])))
         states))

  (define (monotonic-ok? phase last-phase)
    (if (or (eq? last-phase 'fail)
            (eq? phase 'fail)
            (and (eq? phase 'post)
                 (eq? last-phase 'pre)))
        'fail
        phase))

  (let ([prefixes (prefix-states arduino-post)])

    (define (key-transition-ok? key)
      (let* ([pre-val (get-mapping key unity-pre)]
             [post-val (get-mapping key unity-post)]
             [trace (key-trace key prefixes pre-val post-val)])
        (eq? (foldl monotonic-ok? 'post trace)
             'pre)))

    (map key-transition-ok?
         keys)))

(provide max-expression-depth
         max-pin-id
         synth-map
         synth-map-unity-external-vars
         synth-map-unity-internal-vars
         synth-map-arduino-context
         synth-map-arduino-symbolic-state
         synth-map-arduino-state->unity-state
         synth-traces
         synth-traces-initially
         synth-traces-assign
         guarded-trace
         guarded-trace-guard
         guarded-trace-trace
         unity-prog->synth-map
         unity-prog->synth-traces
         monotonic-pre-to-post?)
