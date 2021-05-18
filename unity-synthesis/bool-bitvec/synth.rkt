#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "inversion.rkt"
         "memoize.rkt"
         "types.rkt"
         rosette/lib/match)

;; Given a trace sequence, return the trace sequence without the tail
(define (trim-trace trace tail)
  (if (eq? trace tail)
      '()
      (cons (car trace)
            (trim-trace (cdr trace) tail))))

;; Synthesizes a bool-bitvec trace equal to the unity trace under mapping
;;
;; NOTE: This generates a trace that's correct for concurrent models.  For
;; sequential correctness, you need to ensure that the synthesized trace
;; satisfies the refinement simulation.
(define (unity-trace->memoized-target-trace synth-map memos unity-guard unity-trace)
  (let* ([unity-ext-vars (synth-map-unity-external-vars synth-map)]
         [target-id-writable? (synth-map-target-id-writable? synth-map)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [unity-id->target-st->unity-val
          (synth-map-unity-id->target-state->unity-val synth-map)]
         [unity-id->target-ids (synth-map-unity-id->target-ids synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [unity-st (target-st->unity-st target-st)])

    (define (!noop? k-v)
      (let ([key (car k-v)]
            [val (cdr k-v)])
        (not (concrete-eq? val
                           (get-mapping key target-st)))))

    ;; Yields triple: (cons depth (cons unity-val synthesized-target-trace))
    (define (try-synth depth unity-id unity-val memoized-values)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [target-ids (unity-id->target-ids unity-id)]
                [writable-ids (filter target-id-writable? target-ids)]
                [target-id-vals (vals (subset-mapping target-ids target-st))]
                [target-other-vals (vals (inverse-subset-mapping target-ids target-st))]
                [relevant-vals (append target-id-vals
                                       memoized-values
                                       (relevant-values unity-val target-other-vals))]
                [sketch-trace (trace?? writable-ids relevant-vals (max 0 depth) target-st)]
                [mapped-val (unity-id->target-st->unity-val unity-id sketch-trace)]
                [model (synthesize
                        #:forall target-st
                        #:guarantee (begin
                                      (assume unity-guard)
                                      (assert (eq? mapped-val unity-val))))]
                [synthesized-trace (if (sat? model)
                                       (filter !noop?
                                               (trim-trace (evaluate sketch-trace model) target-st))
                                       model)])
           (begin
             (display (format "~a ~a sec. "
                              (sat? model)
                              (- (current-seconds) start-time))
                      (current-error-port))
             (if (sat? model)
                 (begin
                   (display (format "~a~n" synthesized-trace)
                            (current-error-port))
                   (cons depth synthesized-trace))
                 (if (>= depth max-expression-depth)
                     (begin
                       (display (format "~a~n" model)
                                (current-error-port))
                       (cons -1 model))
                     (try-synth (add1 depth) unity-id unity-val memoized-values))))))))

    (define (synth-subtrace subtrace memos synth-traces)
      (if (null? subtrace)
          (cons memos (reverse synth-traces))
          (let* ([unity-k-v (car subtrace)]
                 [unity-key (car unity-k-v)]
                 [unity-val (cdr unity-k-v)]
                 ;; Disable memoization
                 ;; [try-memo-result '()]
                 [try-memo-result (try-memo unity-val memos)]
                 [synth-result (begin
                                 (display (format "[unity-val->subtrace] ~a memo: ~a "
                                                  unity-key
                                                  (pair? try-memo-result))
                                          (current-error-port))
                                 (try-synth -1 unity-key unity-val try-memo-result))]
                 [synth-depth (car synth-result)]
                 [synth-trace (cdr synth-result)]
                 [target-vals (vals synth-trace)])
            (synth-subtrace (cdr subtrace)
                            (if (positive? synth-depth)
                                (cons (cons unity-val target-vals)
                                      memos)
                                memos)
                            (cons synth-trace
                                  synth-traces)))))

    (if (eq? unity-trace unity-st)
        (cons memos '())
        (synth-subtrace (vc-wrapper (trim-trace unity-trace unity-st)) memos '()))))

(provide unity-trace->memoized-target-trace)
