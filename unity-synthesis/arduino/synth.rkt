#lang rosette

(require "../util.rkt"
         "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         "symbolic.rkt")

;; Synthesize Declaration
;; We take an Arduino context, then synthesize the statments to build it.
(define (synth-arduino-declare cxt)
  (define (try-synth exp-depth)
    (let* ([start-time (current-seconds)]
           [sketch (uncond-stmts?? (length cxt) 0 cxt '())]
           [model (solve
                 (assert
                  (let ([next-env (interpret-stmt sketch '() '())])
                    (equal? (environment*-context next-env) cxt))))])
    (begin
      (display (format "try-synth expr ~a in ~a sec.~n"
                       exp-depth (- (current-seconds) start-time))
               (current-error-port))
      (if (sat? model)
          (evaluate sketch model)
          (if (>= exp-depth max-expression-depth)
              (error 'synth-arduino-declare
                     "Synthesis failure for context ~a" cxt)
              (try-synth (add1 exp-depth)))))))

  (try-synth 0))

(define (synth-arduino-setup unity-prog)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (let* ([ext-vars (unity:context->external-vars unity-cxt)]
            [int-vars (unity:context->internal-vars unity-cxt)]
            [s-map (unity-context->synth-map unity-cxt)]
            [arduino-cxt (synth-map-arduino-context s-map)]
            [arduino-pre-state (symbolic-state arduino-cxt)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state s-map)]
            [arduino-variable-declarations (synth-arduino-declare arduino-cxt)]
            [unity-pre-state (arduino-st->unity-st arduino-pre-state)]
            [unity-pre-environment (unity:interpret-declare unity-prog unity-pre-state)]
            [unity-post-environment (unity:interpret-initially
                                     unity-prog
                                     unity-pre-environment)]
            [unity-post-state (unity:environment*-state unity-post-environment)])

       (define (try-synth stmt-depth exp-depth)
         (let* ([start-time (current-seconds)]
                [sketch (append arduino-variable-declarations
                                (uncond-stmts?? stmt-depth exp-depth arduino-cxt '()))]
                [arduino-post-environment (interpret-stmt sketch '() arduino-pre-state)]
                [arduino-post-cxt (environment*-context arduino-post-environment)]
                [arduino-post-state (environment*-state arduino-post-environment)]
                [model (synthesize
                        #:forall
                        arduino-pre-state
                        #:guarantee
                        (assert
                         (and
                          (equal? arduino-post-cxt arduino-cxt)
                          (map-eq-modulo-keys?
                           int-vars
                           (arduino-st->unity-st arduino-post-state)
                           unity-post-state)
                          (monotonic-transition-equiv? ext-vars
                                                       arduino-pre-state
                                                       arduino-post-state
                                                       unity-pre-state
                                                       unity-post-state
                                                       arduino-st->unity-st))))])
           (begin
             (display (format "try-synth stmt/expr ~a/~a in ~a sec.~n"
                              stmt-depth exp-depth (- (current-seconds) start-time))
                      (current-error-port))
             (if (sat? model)
                 (evaluate sketch model)
                 (if (>= stmt-depth max-statement-depth)
                     (if (>= exp-depth max-expression-depth)
                         (error 'synth-arduino-setup
                                "synthesis failure for statement ~a" initially)
                         (try-synth (0 (add1 exp-depth))))
                     (try-synth (add1 stmt-depth) exp-depth))))))

       (try-synth 0 0))]))

(define (synth-arduino-assign unity-prog snippets)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (let* ([ext-vars (unity:context->external-vars unity-cxt)]
            [int-vars (unity:context->internal-vars unity-cxt)]
            [s-map (unity-context->synth-map unity-cxt)]
            [arduino-cxt (synth-map-arduino-context s-map)]
            [arduino-pre-state (symbolic-state arduino-cxt)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state s-map)]
            [unity-pre-state (arduino-st->unity-st arduino-pre-state)]
            [unity-pre-environment (unity:environment*
                                    unity-cxt
                                    unity-pre-state)]
            [unity-post-environment (unity:interpret-assign
                                     unity-prog
                                     unity-pre-environment)]
            [unity-post-state (unity:environment*-state unity-post-environment)])

       (define (try-synth cond-depth stmt-depth exp-depth)
         (let* ([start-time (current-seconds)]
                [sketch (cond-stmts?? cond-depth stmt-depth exp-depth arduino-cxt snippets)]
                [arduino-post-environment (interpret-stmt sketch arduino-cxt arduino-pre-state)]
                [arduino-post-cxt (environment*-context arduino-post-environment)]
                [arduino-post-state (environment*-state arduino-post-environment)]
                [model (synthesize
                        #:forall
                        arduino-pre-state
                        #:guarantee
                        (assert
                         (let ([arduino-post-environment
                                (interpret-stmt sketch arduino-cxt arduino-pre-state)])
                           (and
                            (equal? arduino-post-cxt arduino-cxt)
                            (map-eq-modulo-keys?
                             int-vars
                             (arduino-st->unity-st arduino-post-state)
                             unity-post-state)
                            (monotonic-transition-equiv? ext-vars
                                                         arduino-pre-state
                                                         arduino-post-state
                                                         unity-pre-state
                                                         unity-post-state
                                                         arduino-st->unity-st)))))])
           (begin
             (display (format "try-synth cond/stmt/expr ~a/~a/~a in ~a sec.~n"
                              cond-depth stmt-depth exp-depth (- (current-seconds) start-time))
                      (current-error-port))
             (if (sat? model)
                 (evaluate sketch model)
                 (if (>= stmt-depth max-statement-depth)
                     (if (>= cond-depth max-condition-depth)
                         (if (>= exp-depth max-expression-depth)
                             (error 'synth-arduino-assign
                                    "Synthesis failure for statement ~a" assign)
                             (try-synth 0 0 (add1 exp-depth)))
                         (try-synth (add1 cond-depth) 0 exp-depth))
                     (try-synth cond-depth (add1 stmt-depth) exp-depth))))))

       (try-synth 0 0 0))]))

(provide synth-arduino-declare
         synth-arduino-setup
         synth-arduino-assign)
