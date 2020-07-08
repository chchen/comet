#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "inversion.rkt"
         "mapping.rkt"
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

;; unity_program -> list[target expressions]
(define (buffer-predicates unity-prog synthesis-map)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      _
      _)

     (let* ([target-cxt (synth-map-target-context synthesis-map)]
            [target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-st (synth-map-target-state synthesis-map)]
            [unity-stobj (unity:stobj (target-st->unity-st target-st))])

       (define (try-synth exp-depth predicate buffer-id guard)
         (let* ([start-time (current-seconds)]
                [sketch (begin
                          (clear-asserts!)
                          (boolexp?? exp-depth target-cxt))]
                [unity-expr (apply predicate (list buffer-id))]
                [target-val (evaluate-expr sketch target-st)]
                [guard-val (unity:evaluate-expr guard unity-cxt unity-stobj)]
                [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-stobj)]
                [eval-eq? (eq? target-val unity-val)]
                [model (synthesize
                          #:forall target-st
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
