#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../util.rkt"
         "mapping.rkt"
         "semantics.rkt"
         rosette/lib/match)

(define (verify-ok? verifier-output)
  (andmap (lambda (t)
            (eq? t 'ok))
          verifier-output))

(define (verify-state synth-map unity-post-st target-post-st)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [target-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (target-st->unity-st target-post-st)
                                           unity-post-st)]
         [model (verify (assert post-st-eq?))])
    (if (sat? model)
        (let* ([bad-target-st (evaluate target-st model)])
          (cons 'counterexample (target-st->unity-st bad-target-st)))
        'ok)))

(define (verify-verilog-reset unity-prog target-module)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [target-env (environment* target-cxt target-st)]
         [unity-initially-st (unity-prog->initially-state unity-prog synth-map)]
         [target-reset-env (interpret-module-reset target-module target-env)]
         [target-reset-st (environment*-state target-reset-env)])
    (verify-state synth-map unity-initially-st target-reset-st)))

(define (verify-verilog-clock unity-prog target-module)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [target-env (environment* target-cxt target-st)]
         [unity-assign-st (unity-prog->assign-state unity-prog synth-map)]
         [target-clock-env (interpret-module-clock target-module target-env)]
         [target-clock-st (environment*-state target-clock-env)])
    (verify-state synth-map unity-assign-st target-clock-st)))

(define (verify-verilog-module unity-prog target-module)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [target-cxt (synth-map-target-context synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [target-env (environment* target-cxt target-st)]
         [unity-initially-st (unity-prog->initially-state unity-prog synth-map)]
         [unity-assign-st (unity-prog->assign-state unity-prog synth-map)]
         [target-reset-env (interpret-module-reset target-module target-env)]
         [target-clock-env (interpret-module-clock target-module target-env)]
         [target-reset-st (environment*-state target-reset-env)]
         [target-clock-st (environment*-state target-clock-env)])
    (list (verify-state synth-map unity-initially-st target-reset-st)
          (verify-state synth-map unity-assign-st target-clock-st))))

(provide verify-ok?
         verify-state
         verify-verilog-reset
         verify-verilog-clock
         verify-verilog-module)
