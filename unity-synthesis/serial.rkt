#lang rosette

(require "unity/syntax.rkt"
         "arduino/synth.rkt"
         "arduino/channel.rkt"
         "arduino/buffer.rkt"
         "arduino/inversion.rkt"
         "arduino/semantics.rkt"
         "arduino/symbolic.rkt"
         (prefix-in arduino: "arduino/environment.rkt"))

(define channel-test
  (unity*
   (declare*
    (list (cons 'o 'send-channel)
          (cons 'i 'recv-channel)))
   (initially*
    '())
   (assign*
    (list (:=* (list 'i 'o)
               (case*
                (list (cons (list 'empty
                                  (message* (value* 'i)))
                            (and* (full?* 'i)
                                  (empty?* 'o))))))))))

(define recv-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 'r 'recv-buf)))
   (initially*
    (:=* (list 'x
               'r)
         (list #f
               (empty-recv-buf* 8))))
   (assign*
    (list (:=* (list 'r)
               (case*
                (list (cons (recv-buf-put* 'r 'x)
                            (not* (recv-buf-full?* 'r))))))))))

(define send-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 's 'send-buf)))
   (initially*
    (:=* (list 'x
               's)
         (list #f
               (nat->send-buf* 8 1))))
   (assign*
    (list (:=* (list 'x)
               (case*
                (list (cons (send-buf-get* 's)
                            (not* (send-buf-empty?* 's))))))))))

(define buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 'r 'recv-buf)
          (cons 's 'send-buf)))
   (initially*
    (:=* (list 'x
               'r
               's)
         (list #f
               (empty-recv-buf* 8)
               (nat->send-buf* 8 42))))
   '()))

(define type-test
  (unity*
   (declare*
    (list (cons 'b 'boolean)
          (cons 'n 'natural)
          (cons 'r 'recv-buf)
          (cons 's 'send-buf)
          (cons 'i 'recv-channel)
          (cons 'o 'send-channel)))
   (initially*
    (:=* (list 'b 'n 'r 's 'o)
         (list #f
               42
               (empty-recv-buf* 8)
               (nat->send-buf* 8 42)
               'empty)))
   (assign*
    '())))

;; (define (sym-count u)
;;   (length (symbolics u)))

;; (match type-test
;;   [(unity*
;;     (declare* unity-cxt)
;;     initially
;;     assign)
;;    (let* ([mapping (unity-context->synth-map unity-cxt)]
;;           [arduino-cxt (synth-map-arduino-context mapping)]
;;           [state (symbolic-state arduino-cxt)]
;;           [preds (append (channel-predicates type-test)
;;                          (buffer-predicates type-test))])
;;      (list
;;       (cons 'expr
;;             (map (lambda (d)
;;                    (sym-count
;;                     (exp?? d arduino-cxt '())))
;;                  depths))
;;       (cons 'expr-pred
;;             (map (lambda (d)
;;                    (sym-count
;;                     (exp?? d arduino-cxt preds)))
;;                  depths))
;;       (cons 'eval-expr
;;             (map (lambda (d)
;;                    (sym-count
;;                     (evaluate-expr (exp?? d arduino-cxt '())
;;                                    arduino-cxt
;;                                    state)))
;;                  depths))
;;       (cons 'eval-expr-pred
;;             (map (lambda (d)
;;                    (sym-count
;;                     (evaluate-expr (exp?? d arduino-cxt preds)
;;                                    arduino-cxt
;;                                    state)))
;;                  depths))))])

;; (match type-test
;;   [(unity*
;;     (declare* unity-cxt)
;;     initially
;;     assign)
;;    (let* ([mapping (unity-context->synth-map unity-cxt)]
;;           [arduino-cxt (synth-map-arduino-context mapping)]
;;           [preds (append (channel-predicates type-test)
;;                          (buffer-predicates type-test))])
;;      (map (lambda (e)
;;             (map sym-count
;;                  (map (lambda (d)
;;                         (uncond-stmts?? d e arduino-cxt preds))
;;                       '(1 2 3 4 5 6 7 8 9))))
;;           '(0 1 2 3 4)))])

;; (match type-test
;;   [(unity*
;;     (declare* unity-cxt)
;;     initially
;;     assign)
;;    (let* ([mapping (unity-context->synth-map unity-cxt)]
;;           [arduino-cxt (synth-map-arduino-context mapping)]
;;           [preds (append (channel-predicates type-test)
;;                          (buffer-predicates type-test))])
;;      (map (lambda (e)
;;             (map (lambda (s)
;;                    (map sym-count
;;                         (map (lambda (c)
;;                                (cond-stmts?? c s e arduino-cxt preds))
;;                              '(4))))
;;                  '(4)))
;;           '(4)))])

(define sender
  (unity*
   (declare*
    (list (cons 'out 'send-channel)
          (cons 'buf 'send-buf)
          (cons 'val 'natural)
          (cons 'cycle 'boolean)))
   (initially*
    (:=* (list 'out
               'cycle
               'val)
         (list 'empty
               #t
               42)))
   (assign*
    (list (:=* (list 'out
                     'buf
                     'cycle)
               (case*
                (list (cons (list (message* (send-buf-get* 'buf))
                                  (send-buf-next* 'buf)
                                  #f)
                            (and* (empty?* 'out)
                                  (not* (send-buf-empty?* 'buf))))
                      (cons (list 'out
                                  (nat->send-buf* 8 'val)
                                  #f)
                            (and* (empty?* 'out)
                                  (or* (send-buf-empty?* 'buf)
                                       'cycle))))))))))

(define receiver
  (unity*
   (declare*
    (list (cons 'in 'recv-channel)
          (cons 'buf 'recv-buf)
          (cons 'rcvd 'boolean)
          (cons 'val 'natural)))
   (initially*
    (:=* (list 'buf
               'rcvd)
         (list (empty-recv-buf* 8)
               #f)))
   (assign*
    (list (:=* (list 'in
                     'buf
                     'rcvd
                     'val)
               (case*
                (list (cons (list 'empty
                                  (recv-buf-put* 'buf (value* 'in))
                                  'rcvd
                                  'val)
                            (and* (full?* 'in)
                                  (not* (recv-buf-full?* 'buf))))
                      (cons (list 'in
                                  (empty-recv-buf* 8)
                                  #t
                                  (recv-buf->nat* 'buf))
                            (recv-buf-full?* 'buf)))))))))

(define (snippets unity-prog)
  (append (channel-predicates unity-prog)
          (buffer-predicates unity-prog)))
