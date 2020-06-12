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

;; construct a list of arduino expressions that correspond to the
;; channel predicates full?* and empty?* over the channels declared
;; in the UNITY context
;;
;; unity_program -> list[arduino expressions]
(define (channel-predicates unity-prog synthesis-map)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      _
      _)

     (let* ([arduino-cxt (synth-map-arduino-context synthesis-map)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]
            [arduino-st (synth-map-arduino-symbolic-state synthesis-map)]
            [unity-stobj (unity:stobj (arduino-st->unity-st arduino-st))])

            (define (try-synth exp-depth predicate channel-id)
              (let* ([start-time (current-seconds)]
                     [sketch (begin
                               (clear-asserts!)
                               (exp?? exp-depth arduino-cxt '()))]
                     [unity-expr (apply predicate (list channel-id))]
                     [arduino-val (evaluate-expr sketch arduino-cxt arduino-st)]
                     [unity-val (unity:evaluate-expr unity-expr unity-cxt unity-stobj)]
                     [eval-eq? (eq? (bitvector->bool arduino-val)
                                    unity-val)]
                     [model (synthesize
                               #:forall arduino-st
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
