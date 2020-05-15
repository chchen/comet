#lang rosette/safe

(require "../util.rkt"
         "environment.rkt"
         "inversion.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         rosette/lib/match
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt"))

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
(define (buffer-predicates unity-prog synthesis-map)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      _
      _)

     (let* ([arduino-cxt (synth-map-arduino-context synthesis-map)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]
            [arduino-st (synth-map-arduino-symbolic-state synthesis-map)]
            [unity-stobj (unity:stobj (arduino-st->unity-st arduino-st))]
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
                   [arduino-val (evaluate-expr sketch arduino-cxt arduino-st)]
                   [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-stobj)]
                   [model (synthesize
                           #:forall
                           arduino-st
                           #:assume
                           (assert
                            (boolean? unity-val))
                           #:guarantee
                           (assert
                            (eq? (byte->bool arduino-val)
                                 unity-val)))])
              (begin
                (display (format "try-synth expr ~a ~a in ~a sec.~n"
                                 unity-expr exp-depth (- (current-seconds) start-time))
                         (current-error-port))
                (if (sat? model)
                    (evaluate sketch model)
                    (if (>= exp-depth max-expression-depth)
                        (format "synthesis failure for expr ~a" unity-expr)
                        (try-synth (add1 exp-depth)))))))

          (cons (try-synth 0)
                (helper predicate tail))]))

     (append (helper unity:send-buf-empty?* send-buffers)
             (helper unity:send-buf-get* send-buffers)
             (helper unity:recv-buf-full?* recv-buffers)))]))

(provide buffer-predicates)
