#lang rosette

(require "../util.rkt"
         "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         "symbolic.rkt")

;; Synthesize snippets related to buffers!
;; send-buf-empty? (expr)
;; recv-buf-full? (expr)
;; send-buf-get (expr)

;; Statements that take buffer values
;; recv-buf->nat (stmt)
;; empty-recv-buf (stmt)

;; Statments that take any old byte value
;; nat->send-buf (stmt that takes a byte?)
;; recv-buf-put (stmt that takes a byte?)

;; unity_program -> list[arduino expressions]
(define (buffer-predicates unity-prog)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      _
      _)

     (let* ([s-map (unity-context->synth-map unity-cxt)]
            [arduino-cxt (synth-map-arduino-context s-map)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state s-map)]
            [arduino-state (symbolic-state arduino-cxt)]
            [unity-state (arduino-st->unity-st arduino-state)]
            [send-buffers (type-in-context 'send-buf unity-cxt)]
            [recv-buffers (type-in-context 'recv-buf unity-cxt)])

     (define (helper predicate buffers)
       (match buffers
         ['() '()]
         [(cons buffer-id tail)

          (define (try-synth exp-depth)
            (let* ([start-time (current-seconds)]
                   [sketch (exp?? exp-depth arduino-cxt '())]
                   [unity-expr (apply predicate (list buffer-id))]
                   [arduino-val (evaluate-expr sketch arduino-cxt arduino-state)]
                   [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-state)]
                   [model (synthesize
                           #:forall
                           arduino-state
                           #:assume
                           (assert
                            (boolean? unity-val))
                           #:guarantee
                           (assert
                            (eq?
                             (byte->bool arduino-val)
                             unity-val)))])
              (begin
                (display unity-expr
                         (current-error-port))
                (display (format "try-synth expr ~a in ~a sec.~n"
                                 exp-depth (- (current-seconds) start-time))
                         (current-error-port))
                (if (sat? model)
                    (evaluate sketch model)
                    (if (>= exp-depth max-expression-depth)
                        (error 'synth-arduino-declare
                               "Synthesis failure for expr ~a" unity-expr)
                        (try-synth (add1 exp-depth)))))))

          (cons (try-synth 0)
                (helper predicate tail))]))

     (append (helper unity:send-buf-empty?* send-buffers)
             (helper unity:send-buf-get* send-buffers)
             (helper unity:recv-buf-full?* recv-buffers)))]))

(provide buffer-predicates)
