#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../unity/concretize.rkt"
         "../util.rkt"
         "mapping.rkt"
         "semantics.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         rosette/lib/match)

(define (verify-env synth-map unity-post-stobj target-post-env)
  (let* ([ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [target-post-st (environment*-state target-post-env)])

    (define (verify-helper unity-guard unity-post-st)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [concretized-post-st (concretize-val target-post-st unity-guard)]
                [model (verify (begin
                                 (assume unity-guard)
                                 (assert
                                  (map-eq-modulo-keys? all-vars
                                                       (target-st->unity-st concretized-post-st)
                                                       unity-post-st))))])
           (begin (display (format "[verify-helper] ~a ~a sec. case: ~a~n"
                                   (not (sat? model))
                                   (- (current-seconds) start-time)
                                   unity-guard)
                           (current-error-port))
                  (if (sat? model)
                      (list
                       (cons 'target-pre
                             (evaluate target-st model)))
                      model))))))

    (if (union? unity-post-stobj)
        (map (lambda (union-pair)
               (verify-helper (car union-pair)
                              (unity:stobj-state (cdr union-pair))))
             (union-contents unity-post-stobj))
        (list
         (verify-helper #t
                        (unity:stobj-state unity-post-stobj))))))

(define (verify-verilog-module unity-prog target-module)
  (begin
    (clear-vc!)
    (clear-terms!)
    (let* ([start-time (current-seconds)]
           [synth-map (unity-prog->synth-map unity-prog)]
           [target-cxt (synth-map-target-context synth-map)]
           [target-st (synth-map-target-state synth-map)]
           [target-env (environment* target-cxt target-st)]
           [unity-initially-stobj (vc-wrapper (unity-prog->initially-stobj unity-prog synth-map))]
           [unity-assign-stobj (vc-wrapper (unity-prog->assign-stobj unity-prog synth-map))]
           [target-reset-env (interpret-module-reset target-module target-env)]
           [target-clock-env (interpret-module-clock target-module target-env)]
           [check (begin (display (format "[pre-verify] vc: ~a~n"
                                          (vc))
                                  (current-error-port))
                         #t)]
           [reset-ok? (verify-env synth-map unity-initially-stobj target-reset-env)]
           [clock-ok? (verify-env synth-map unity-assign-stobj target-clock-env)])
      (begin
        (display (format "[verify-verilog-module] ~a sec.~n"
                         (- (current-seconds) start-time))
                 (current-error-port))
        (list reset-ok? clock-ok?)))))

(provide verify-verilog-module)
