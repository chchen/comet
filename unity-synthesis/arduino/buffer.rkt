#lang rosette/safe

(require "../util.rkt"
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
            [unity-stobj (unity:stobj (arduino-st->unity-st arduino-st))])

       (define (try-synth exp-depth predicate buffer-id guard)
         (let* ([start-time (current-seconds)]
                [sketch (begin
                          (clear-asserts!)
                          (exp?? exp-depth arduino-cxt '()))]
                [unity-expr (apply predicate (list buffer-id))]
                [arduino-val (evaluate-expr sketch arduino-cxt arduino-st)]
                [guard-val (unity:evaluate-expr guard unity-cxt unity-stobj)]
                [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-stobj)]
                [eval-eq? (eq? (bitvector->bool arduino-val)
                               unity-val)]
                [model (synthesize
                          #:forall arduino-st
                          #:assume (assert (and guard-val
                                                (boolean? unity-val)))
                          #:guarantee (assert eval-eq?))])
           (begin
             (display (format "[buffer-predicates] ~a ~a sec. depth: ~a ~a~n"
                              (sat? model)
                              (- (current-seconds) start-time)
                              exp-depth
                              unity-expr)
                      (current-error-port))
             (if (sat? model)
                 (evaluate sketch model)
                 (if (>= exp-depth max-expression-depth)
                     model
                     (try-synth (add1 exp-depth)
                                predicate
                                buffer-id
                                guard))))))

       (define (send-buf-empty buffer-id)
         (try-synth 0 unity:send-buf-empty?* buffer-id #t))

       (define (send-buf-get buffer-id)
         (let ([guard-expr
                (unity:not*
                 (apply unity:send-buf-empty?* (list buffer-id)))])
           (try-synth 0 unity:send-buf-get* buffer-id guard-expr)))

       (define (recv-buf-full buffer-id)
         (try-synth 0 unity:recv-buf-full?* buffer-id #t))

       (let ([unity-send-buffers (type-in-context 'send-buf unity-cxt)]
             [unity-recv-buffers (type-in-context 'recv-buf unity-cxt)])
         (append (map send-buf-empty unity-send-buffers)
                 (map send-buf-get unity-send-buffers)
                 (map recv-buf-full unity-recv-buffers))))]))

(provide buffer-predicates)
