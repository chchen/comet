#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../unity/concretize.rkt"
         "../util.rkt"
         "mapping.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         rosette/lib/match)

(define (verify-stmt synth-map unity-post-stobj arduino-stmt init-cxt?)
  (let* ([ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [arduino-init-cxt (if init-cxt? arduino-cxt '())]
         [arduino-post-env (interpret-stmt arduino-stmt arduino-init-cxt arduino-st)]
         [arduino-post-cxt (environment*-context arduino-post-env)]
         [arduino-post-st (environment*-state arduino-post-env)])

    (define (verify-helper unity-guard unity-post-st)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [concretized-post-st (concretize-val arduino-post-st unity-guard)]
                [model (verify (begin
                                 (assume unity-guard)
                                 (assert
                                  (and (eq? arduino-post-cxt
                                            arduino-cxt)
                                       (map-eq-modulo-keys? all-vars
                                                            (arduino-st->unity-st
                                                             concretized-post-st)
                                                            unity-post-st)
                                       (monotonic-keys-ok? ext-vars
                                                           arduino-st
                                                           concretized-post-st
                                                           unity-st
                                                           unity-post-st
                                                           arduino-st->unity-st)))))])
           (begin (display (format "[verify-helper] ~a ~a sec. case: ~a~n"
                                   (not (sat? model))
                                   (- (current-seconds) start-time)
                                   unity-guard)
                           (current-error-port))
                  (if (sat? model)
                      (list
                       (cons 'arduino-pre
                             (evaluate arduino-st model))
                       (cons 'arduino-post
                             (environment*-state
                              (interpret-stmt arduino-stmt
                                              arduino-cxt
                                              (evaluate arduino-st model)))))
                      model))))))

    (if (union? unity-post-stobj)
        (map (lambda (union-pair)
               (verify-helper (car union-pair)
                              (unity:stobj-state (cdr union-pair))))
             (union-contents unity-post-stobj))
        (list
         (verify-helper #t
                        (unity:stobj-state unity-post-stobj))))))

(define (verify-arduino-prog unity-prog arduino-prog)
  (begin
    (clear-vc!)
    (clear-terms!)
    (match arduino-prog
      [(arduino* (setup* setup-stmts)
                 (loop* loop-stmts))
       (let* ([synth-map (unity-prog->synth-map unity-prog)]
              [initially-stobj (vc-wrapper (unity-prog->initially-stobj unity-prog synth-map))]
              [assign-stobj (vc-wrapper (unity-prog->assign-stobj unity-prog synth-map))]
              [check (begin (display (format "[pre-verify] vc: ~a~n" (vc))
                                     (current-error-port))
                            #t)])
         (list (verify-stmt synth-map initially-stobj setup-stmts #f)
               (verify-stmt synth-map assign-stobj loop-stmts #t)))])))

(provide verify-stmt
         verify-arduino-prog)
