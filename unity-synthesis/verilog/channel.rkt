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

;; construct a list of arduino expressions that correspond to the
;; channel predicates full?* and empty?* over the channels declared
;; in the UNITY context
;;
;; unity_program -> list[target expressions]
(define (channel-predicates unity-prog synthesis-map)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      _
      _)

     (let* ([target-cxt (synth-map-target-context synthesis-map)]
            [target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-st (synth-map-target-state synthesis-map)]
            [unity-stobj (unity:stobj (target-st->unity-st target-st))])

            (define (try-synth exp-depth predicate channel-id)
              (let* ([start-time (current-seconds)]
                     [sketch (begin
                               (clear-asserts!)
                               (exp?? exp-depth target-cxt boolean? '()))]
                     [unity-expr (apply predicate (list channel-id))]
                     [target-val (evaluate-expr sketch target-st)]
                     [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-stobj)]
                     [eval-eq? (eq? target-val unity-val)]
                     [model (synthesize
                               #:forall target-st
                               #:assume (assert (boolean? unity-val))
                               #:guarantee (assert eval-eq?))])
                (begin
                  (display (format "[channel-predicates] ~a ~a sec. depth: ~a ~a~n"
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
                                     channel-id))))))

            (define (recv-full channel-id)
              (try-synth 0 unity:full?* channel-id))

            (define (send-empty channel-id)
              (try-synth 0 unity:empty?* channel-id))

            (let ([unity-recv-channels (type-in-context 'recv-channel unity-cxt)]
                  [unity-send-channels (type-in-context 'send-channel unity-cxt)])
              (append (map recv-full unity-recv-channels)
                      (map send-empty unity-send-channels))))]))

(provide channel-predicates)
