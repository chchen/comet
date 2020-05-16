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
             [model (synthesize
                     #:forall
                     arduino-st
                     #:guarantee
                     (assert
                      (eq? (byte->bool arduino-val)
                           guard)))])
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

(define (try-synth-trace guarded-tr synthesis-map snippets)
  (let* ([ext-vars (synth-map-unity-external-vars synthesis-map)]
         [int-vars (synth-map-unity-internal-vars synthesis-map)]
         [arduino-cxt (synth-map-arduino-context synthesis-map)]
         [arduino-start-st (synth-map-arduino-symbolic-state synthesis-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synthesis-map)]
         [unity-start-st (arduino-st->unity-st arduino-start-st)]
         [guard (guarded-trace-guard guarded-tr)]
         [unity-trace (guarded-trace-trace guarded-tr)])

    (define (try-synth stmt-depth exp-depth)
      (let* ([start-time (current-seconds)]
             [sketch (uncond-stmts?? stmt-depth exp-depth arduino-cxt snippets)]
             [arduino-post-env (interpret-stmt sketch
                                               arduino-cxt
                                               arduino-start-st)]
             [arduino-post-cxt (environment*-context arduino-post-env)]
             [arduino-post-st (environment*-state arduino-post-env)]
             [post-states-eq? (map-eq-modulo-keys? (append ext-vars
                                                    int-vars)
                                            (arduino-st->unity-st arduino-post-st)
                                            unity-trace)]
             [ext-vars-monotonic? (monotonic-pre-to-post? ext-vars
                                                          arduino-start-st
                                                          arduino-post-st
                                                          unity-start-st
                                                          unity-trace
                                                          arduino-st->unity-st)]
             [model (synthesize
                     #:forall
                     arduino-start-st
                     #:assume
                     (assert guard)
                     #:guarantee
                     (assert
                      (and
                       (eq? arduino-post-cxt
                            arduino-cxt)
                       post-states-eq?
                       ext-vars-monotonic?)))])
        (begin
          (display (format "try-synth stmt/expr ~a/~a in ~a sec.~n"
                           stmt-depth exp-depth (- (current-seconds) start-time))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= stmt-depth max-statement-depth)
                  (if (>= exp-depth max-expression-depth)
                      (format "synthesis failure for trace ~a" unity-trace)
                      (try-synth 0 (add1 exp-depth)))
                  (try-synth (add1 stmt-depth) exp-depth))))))

    (try-synth 0 0)))

(provide try-synth-guard
         try-synth-trace)
