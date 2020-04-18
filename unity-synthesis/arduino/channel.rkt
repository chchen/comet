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

;; Synthesize snippets related to channels!
;; empty channels?
;; full channels?
;; full? (done)
;; empty? (done)

;; construct a list of arduino expressions that correspond to the
;; channel predicates full?* and empty?* over the channels declared
;; in the UNITY context
;;
;; unity_program -> list[arduino expressions]
(define (channel-predicates unity-prog)
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
            [unity-channels (type-in-context 'channel unity-cxt)])            

     (define (helper predicate channels)
       (match channels
         ['() '()]
         [(cons channel-id tail)

          (define (try-synth exp-depth)
            (let* ([start-time (current-seconds)]
                   [sketch (exp?? exp-depth arduino-cxt)]
                   [unity-expr (apply predicate (list channel-id))]
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

     (append (helper unity:full?* unity-channels)
             (helper unity:empty?* unity-channels)))]))

(provide channel-predicates)
