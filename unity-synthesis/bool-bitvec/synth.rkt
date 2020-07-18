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
  (let* ([unity-ext-vars (synth-map-unity-external-vars synth-map)]
         [target-id-writable? (synth-map-target-id-writable? synth-map)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [unity-id->target-st->unity-val
          (synth-map-unity-id->target-state->unity-val synth-map)]
         [unity-id->target-ids (synth-map-unity-id->target-ids synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [unity-st (target-st->unity-st target-st)])

    (define (monotonic-ordering unity-id trace-suffix)
      (let* ([sketch-trace (begin
                             (clear-asserts!)
                             (trace-permutation?? trace-suffix))]
             [trace-monotonic? (monotonic-ok? unity-id
                                              target-st
                                              (append sketch-trace target-st)
                                              unity-st
                                              unity-trace
                                              target-st->unity-st)]
             [model (synthesize
                     #:forall target-st
                     #:assume (assert unity-guard)
                     #:guarantee (assert trace-monotonic?))])
        (if (sat? model)
            (evaluate sketch-trace model)
            model)))

    (define (try-synth depth unity-id-val)
      (let* ([start-time (current-seconds)]
             [unity-id (car unity-id-val)]
             [unity-val (cdr unity-id-val)]
             [target-ids (unity-id->target-ids unity-id)]
             [writable-ids (filter target-id-writable? target-ids)]
             [target-id-vals (vals (subset-mapping target-ids target-st))]
             [target-other-vals (vals (inverse-subset-mapping target-ids target-st))]
             [relevant-vals (append target-id-vals
                                    (relevant-values unity-val target-other-vals))]
             [sketch-trace (begin
                          (clear-asserts!)
                          (trace?? writable-ids relevant-vals depth target-st))]
             [mapped-val (unity-id->target-st->unity-val unity-id sketch-trace)]
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
                           writable-ids)
                   (current-error-port))
          (if (sat? model)
              (let* ([ext-var? (member unity-id unity-ext-vars)]
                     [synthesized-trace (evaluate sketch-trace model)]
                     [trace-suffix (trim-trace synthesized-trace target-st)])
                (if ext-var?
                    (monotonic-ordering unity-id trace-suffix)
                    trace-suffix))
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
