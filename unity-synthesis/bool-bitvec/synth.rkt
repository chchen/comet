#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "inversion.rkt"
         "types.rkt"
         rosette/lib/match)

;; Given a trace sequence, return the trace sequence without the tail
(define (trim-trace trace tail)
  (if (eq? trace tail)
      '()
      (cons (car trace)
            (trim-trace (cdr trace) tail))))

(define (unity-trace->target-trace synth-map unity-guard unity-trace)
  (let* ([target-cxt (synth-map-target-context synth-map)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [unity-id->target-st->unity-val
          (synth-map-unity-id->target-state->unity-val synth-map)]
         [unity-id->target-ids (synth-map-unity-id->target-ids synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [unity-st (target-st->unity-st target-st)])

    (define (try-synth depth unity-id-val)
      (let* ([start-time (current-seconds)]
             [unity-id (car unity-id-val)]
             [unity-val (cdr unity-id-val)]
             [target-ids (unity-id->target-ids unity-id)]
             [target-id-vals (vals (subset-mapping target-ids target-st))]
             [target-other-vals (vals (inverse-subset-mapping target-ids target-st))]
             [relevant-vals (append target-id-vals
                                    (relevant-values unity-val target-other-vals))]
             [sketch-st (begin
                          (clear-asserts!)
                          (state?? target-ids relevant-vals depth target-st))]
             [mapped-val (unity-id->target-st->unity-val unity-id sketch-st)]
             [model (synthesize
                     #:forall target-st
                     #:assume (assert unity-guard)
                     #:guarantee (assert (eq? mapped-val unity-val)))])
        (begin
          (display (format "[unity-trace->target-trace] ~a ~a sec. depth: ~a uid: ~a ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           depth
                           unity-id
                           relevant-vals
                           target-ids)
                   (current-error-port))
          (if (sat? model)
              (trim-trace (evaluate sketch-st model)
                          target-st)
              (if (>= depth max-expression-depth)
                  model
                  (try-synth (add1 depth) unity-id-val))))))

    (if (eq? unity-trace unity-st)
        '()
        (foldr
         append
         '()
         (map (lambda (k-v)
                (try-synth 0 k-v))
              (trim-trace unity-trace unity-st))))))

(provide unity-trace->target-trace)
