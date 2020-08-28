#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../util.rkt"
         "mapping.rkt"
         "semantics.rkt"
         "syntax.rkt"
         rosette/lib/match)

(define (verify-stmt synth-map unity-post-st arduino-stmt init-cxt?)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [arduino-post-env (interpret-stmt arduino-stmt
                                           (if init-cxt?
                                               arduino-cxt
                                               '())
                                           arduino-st)]
         [arduino-post-cxt (environment*-context arduino-post-env)]
         [arduino-post-st (environment*-state arduino-post-env)]
         [context-ok? (eq? arduino-post-cxt
                           arduino-cxt)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (arduino-st->unity-st arduino-post-st)
                                           unity-post-st)]
         [monotonic? (monotonic-keys-ok? ext-vars
                                         arduino-st
                                         arduino-post-st
                                         unity-st
                                         unity-post-st
                                         arduino-st->unity-st)]
         [model (verify (assert (and context-ok? post-st-eq? monotonic?)))])
    (if (sat? model)
        (let* ([bad-arduino-st (evaluate arduino-st model)]
               [bad-unity-st (arduino-st->unity-st bad-arduino-st)])
          (list (cons 'arduino bad-arduino-st)
                (cons 'unity bad-unity-st)
                (cons 'arduino-post (interpret-stmt arduino-stmt arduino-cxt bad-arduino-st))))
        'ok)))

(define (verify-arduino-prog unity-prog arduino-prog)
  (match arduino-prog
    [(arduino* (setup* setup-stmts)
               (loop* loop-stmts))
     (let* ([synth-map (unity-prog->synth-map unity-prog)]
            [synth-tr (unity-prog->synth-traces unity-prog synth-map)]
            [initially-state (unity-prog->initially-state unity-prog synth-map)]
            [assign-state (unity-prog->assign-state unity-prog synth-map)])
       (list (verify-stmt synth-map initially-state setup-stmts #f)
             (verify-stmt synth-map assign-state loop-stmts #t)))]))

(provide verify-stmt
         verify-arduino-prog)
