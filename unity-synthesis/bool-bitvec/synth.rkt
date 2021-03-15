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
(define (unity-trace->memoized-target-trace synth-map assumptions memos unity-guard unity-trace)
  (let* ([unity-ext-vars (synth-map-unity-external-vars synth-map)]
         [target-id-writable? (synth-map-target-id-writable? synth-map)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [unity-id->target-st->unity-val
          (synth-map-unity-id->target-state->unity-val synth-map)]
         [unity-id->target-ids (synth-map-unity-id->target-ids synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [unity-st (target-st->unity-st target-st)])

    ;; Yields triple: (cons depth (cons unity-val synthesized-target-trace))
    (define (try-synth depth unity-id-val memoized-values)
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
                             (if (< depth 0)
                                 (trace?? writable-ids memoized-values 0 target-st)
                                 (trace?? writable-ids relevant-vals depth target-st)))]
             [mapped-val (unity-id->target-st->unity-val unity-id sketch-trace)]
             [model (synthesize
                     #:forall target-st
                     #:assume (assert (and assumptions
                                           unity-guard))
                     #:guarantee (assert (eq? mapped-val unity-val)))]
             [synthesized-trace (if (sat? model)
                                    (trim-trace (evaluate sketch-trace model) target-st)
                                    model)])
        (begin
          (display (format "~a ~a sec. "
                           (sat? model)
                           (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (begin
                (display (format "~a~n"
                                 synthesized-trace)
                         (current-error-port))
                (cons depth
                      (cons unity-val
                            synthesized-trace)))
              (if (>= depth max-expression-depth)
                  (begin
                    (display (format "~a~n" model)
                             (current-error-port))
                    (cons -1
                          (cons unity-val
                                model)))
                  (try-synth (add1 depth)
                             unity-id-val
                             '()))))))

    (if (eq? unity-trace unity-st)
        (cons memos '())
        (let* ([subtrace-to-synthesize (trim-trace unity-trace unity-st)]
               [synth-results (map (lambda (k-v)
                                     (let* ([unity-val (cdr k-v)]
                                            [try-memo-result (try-memo unity-val memos)])
                                       (begin
                                         (display (format "[unity-val->subtrace] ~a "
                                                          (car k-v))
                                                  (current-error-port))
                                         (try-synth -1 k-v try-memo-result))))
                                   subtrace-to-synthesize)]
               [fresh-synth-results (filter (lambda (result)
                                              (positive? (car result)))
                                            synth-results)]
               [new-memos (map (lambda (result)
                                 (let* ([unity-val (cadr result)]
                                        [synthesized-trace (cddr result)]
                                        [target-values (map cdr synthesized-trace)])
                                   (cons unity-val target-values)))
                               fresh-synth-results)]
               [synthesized-traces (apply append (map cddr synth-results))])
          (cons (append memos new-memos)
                synthesized-traces)))))

(provide unity-trace->memoized-target-trace)
