#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "../bool-bitvec/types.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match
         ;; unsafe! only allowed for concrete evaluation
         (only-in racket/base string->symbol))

(define max-expression-depth
  4)

(define max-pin-id
  21)

;; Take a UNITY context and produce a corresponding synthesis map
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

  ;; (f: symbol -> (fn: target_state -> unity_val))
  ;; -> target_state
  ;; -> unity_state
  (define (state-mapper state-map state)
    (match state-map
      ['() '()]
      [(cons (cons id fn) tail)
       (cons (cons id (fn state))
             (state-mapper tail state))]))

  ;; (f: symbol -> (fn: target_state -> unity_val))
  ;; -> unity_id
  ;; -> target_state
  ;; -> unity_val
  (define (state-id-mapper state-map id state)
    (let ([id-fn (get-mapping id state-map)])
      (if (null? id-fn)
          '()
          (id-fn state))))

  (define (helper unity-cxt target-cxt state-map inv-map current-pin)
    (match unity-cxt
      ['() (synth-map (unity:context->external-vars unity-context)
                      (unity:context->internal-vars unity-context)
                      target-cxt
                      (symbolic-state target-cxt)
                      (lambda (st) (state-mapper state-map st))
                      (lambda (id st) (state-id-mapper state-map id st))
                      (lambda (id) (get-mapping id inv-map)))]
      [(cons (cons id 'boolean) tail)
       (helper tail
               (cons (cons id (reg* 1 id))
                     target-cxt)
               (cons (cons id (lambda (st)
                                (get-mapping id st)))
                     state-map)
               (cons (cons id (list id))
                     inv-map)
               current-pin)]
      [(cons (cons id 'natural) tail)
       (helper tail
               (cons (cons id (reg* vect-len id))
                     target-cxt)
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
                 (append (list (cons req-id (input* (wire* 1 req-id)))
                               (cons ack-id (output* (reg* 1 ack-id)))
                               (cons val-id (input* (wire* 1 val-id))))
                         target-cxt)
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
                 (append (list (cons req-id (output* (reg* 1 req-id)))
                               (cons ack-id (input* (wire* 1 ack-id)))
                               (cons val-id (output* (reg* 1 val-id))))
                         target-cxt)
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
                 (append (list (cons rcvd-id (reg* vect-len rcvd-id))
                               (cons vals-id (reg* vect-len vals-id)))
                         target-cxt)
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
                 (append (list (cons sent-id (reg* vect-len sent-id))
                               (cons vals-id (reg* vect-len vals-id)))
                         target-cxt)
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

(provide max-expression-depth
         unity-prog->synth-map)
