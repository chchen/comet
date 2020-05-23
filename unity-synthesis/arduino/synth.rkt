#lang rosette/safe

(require "../util.rkt"
         "environment.rkt"
         "inversion.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt"))

(define (try-synth-guard guarded-tr synthesis-map snippets)
  (let* ([arduino-cxt (synth-map-arduino-context synthesis-map)]
         [arduino-st (synth-map-arduino-symbolic-state synthesis-map)]
         [guard (guarded-trace-guard guarded-tr)])

    (define (try-synth exp-depth)
      (let* ([start-time (current-seconds)]
             [sketch (exp?? exp-depth arduino-cxt snippets)]
             [arduino-val (evaluate-expr sketch arduino-cxt arduino-st)]
             [model (begin
                      (clear-asserts!)
                      (synthesize
                       #:forall
                       arduino-st
                       #:guarantee
                       (assert
                        (eq? (byte->bool arduino-val)
                             guard))))])
        (begin
          (display (format "try-synth expr ~a in ~a sec.~n"
                           exp-depth (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= exp-depth max-expression-depth)
                  (format "synthesis failure for guard ~a" guard)
                  (try-synth (add1 exp-depth)))))))

    (try-synth 0)))

(define (try-synth-trace guarded-tr synthesis-map initialized-cxt? snippets)
  (let* ([ext-vars (synth-map-unity-external-vars synthesis-map)]
         [int-vars (synth-map-unity-internal-vars synthesis-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-arduino-context synthesis-map)]
         [stmt-limit (length arduino-cxt)]
         [arduino-start-st (synth-map-arduino-symbolic-state synthesis-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]
         [unity-start-st (arduino-st->unity-st arduino-start-st)]
         [guard (guarded-trace-guard guarded-tr)]
         [unity-trace (guarded-trace-trace guarded-tr)])

    (define (try-context stmt-depth)
      (let* ([start-time (current-seconds)]
             [sketch (context-stmts?? stmt-depth arduino-cxt)]
             [arduino-post-env (interpret-stmt sketch '() arduino-start-st)]
             [arduino-post-cxt (environment*-context arduino-post-env)]
             [arduino-post-st (environment*-state arduino-post-env)]
             [states-unchanged? (eq? arduino-start-st arduino-post-st)]
             [post-context-valid? (eq? arduino-post-cxt
                                       arduino-cxt)]
             [model (begin
                      (clear-asserts!)
                      (synthesize
                       #:forall
                       arduino-start-st
                       #:guarantee
                       (assert
                        (and post-context-valid?
                             states-unchanged?))))])
        (begin
          (display (format "try-context stmt/expr ~a in ~a sec.~n"
                           stmt-depth (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= stmt-depth stmt-limit)
                  (format "context synthesis failure for trace ~a" unity-trace)
                  (try-context (add1 stmt-depth)))))))

    (define (try-state stmt-depth exp-depth)
      (let* ([start-time (current-seconds)]
             [sketch (state-stmts?? stmt-depth exp-depth arduino-cxt snippets)]
             [arduino-post-env (interpret-stmt sketch arduino-cxt arduino-start-st)]
             [arduino-post-cxt (environment*-context arduino-post-env)]
             [context-unchanged? (eq? arduino-cxt arduino-post-cxt)]
             [arduino-post-st (environment*-state arduino-post-env)]
             [post-states-eq? (map-eq-modulo-keys?
                               all-vars
                               (arduino-st->unity-st arduino-post-st)
                               unity-trace)]
             [ext-vars-monotonic? (monotonic-pre-to-post?
                                   ext-vars
                                   arduino-start-st
                                   arduino-post-st
                                   unity-start-st
                                   unity-trace
                                   arduino-st->unity-st)]
             [model (begin
                      (clear-asserts!)
                      (synthesize
                       #:forall
                       arduino-start-st
                       #:assume
                       (assert guard)
                       #:guarantee
                       (assert
                        (and context-unchanged?
                             post-states-eq?
                             ext-vars-monotonic?))))])
        (begin
          (display (format "try-state stmt/expr ~a/~a in ~a sec.~n"
                           stmt-depth exp-depth (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= stmt-depth stmt-limit)
                  (if (>= exp-depth max-expression-depth)
                      (format "state synthesis failure for trace ~a" unity-trace)
                      (try-state 0 (add1 exp-depth)))
                  (try-state (add1 stmt-depth) exp-depth))))))

    (if initialized-cxt?
        (try-state 0 0)
        (append (try-context 0)
                (try-state 0 0)))))

(define (try-synth-loop unity-prog synthesis-map exps stmts)
  (let* ([cond-limit (length exps)]
         [ext-vars (synth-map-unity-external-vars synthesis-map)]
         [int-vars (synth-map-unity-internal-vars synthesis-map)]
         [all-vars (append ext-vars int-vars)]

         [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]

         [arduino-cxt (synth-map-arduino-context synthesis-map)]
         [arduino-start-st (synth-map-arduino-symbolic-state synthesis-map)]

         [unity-start-st (arduino-st->unity-st arduino-start-st)]
         [unity-start-stobj (unity:stobj unity-start-st)]
         [unity-start-env (unity:interpret-declare unity-prog unity-start-stobj)]

         [unity-post-env (unity:interpret-assign unity-prog unity-start-env)]
         [unity-post-st (unity:stobj-state
                         (unity:environment*-stobj unity-post-env))])

    (define (try-cond cond-depth)
      (let* ([start-time (current-seconds)]
             [sketch (cond-stmts?? cond-depth exps stmts)]

             [arduino-post-env (interpret-stmt sketch arduino-cxt arduino-start-st)]
             [arduino-post-cxt (environment*-context arduino-post-env)]
             [arduino-post-st (environment*-state arduino-post-env)]

             [context-unchanged? (eq? arduino-cxt arduino-post-cxt)]
             [post-states-eq? (map-eq-modulo-keys?
                               all-vars
                               (arduino-st->unity-st arduino-post-st)
                               unity-post-st)]
             [ext-vars-monotonic? (monotonic-pre-to-post?
                                   ext-vars
                                   arduino-start-st
                                   arduino-post-st
                                   unity-start-st
                                   unity-post-st
                                   arduino-st->unity-st)]
             [model (begin
                      (clear-asserts!)
                      (synthesize
                       #:forall
                       arduino-start-st
                       #:guarantee
                       (assert
                        (and context-unchanged?
                             post-states-eq?
                             ext-vars-monotonic?))))])
        (begin
          (display (format "try-cond ~a in ~a sec.~n"
                           cond-depth (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= cond-depth cond-limit)
                  (format "loop synthesis failure for prog ~a" unity-prog)
                  (try-cond (add1 cond-depth)))))))

    (try-cond 0)))

(provide try-synth-guard
         try-synth-trace
         try-synth-loop)
