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

     (let* ([s-map (unity-context->synth-map unity-cxt)]
            [arduino-cxt (synth-map-arduino-context s-map)]
            [arduino-pre-state (symbolic-state arduino-cxt)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state s-map)]
            [arduino-variable-declarations (synth-arduino-declare arduino-cxt)]
            [unity-pre-environment (unity:interpret-declare unity-prog '())]
            [unity-post-environment (unity:interpret-initially
                                     unity-prog
                                     unity-pre-environment)])

       (define (try-synth stmt-depth exp-depth)
         (let* ([start-time (current-seconds)]
                [sketch (append arduino-variable-declarations
                                (uncond-stmts?? stmt-depth exp-depth arduino-cxt '()))]
                [model (synthesize
                        #:forall
                        arduino-pre-state
                        #:guarantee
                        (assert
                         (let ([arduino-post-environment
                                (interpret-stmt sketch '() arduino-pre-state)])
                           (and
                            (equal?
                             (environment*-context arduino-post-environment)
                             arduino-cxt)
                            (map-eq-modulo-keys-test-reference?
                             (keys unity-cxt)
                             (arduino-st->unity-st
                              (environment*-state arduino-post-environment))
                             (unity:environment*-state
                              unity-post-environment))))))])
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
                         (try-synth (1 (add1 exp-depth))))
                     (try-synth (add1 stmt-depth) exp-depth))))))

       (try-synth 1 0))]))

(define (synth-arduino-assign unity-prog)
  (match unity-prog
    [(unity:unity*
      (unity:declare* unity-cxt)
      initially
      assign)
     (let* ([s-map (unity-context->synth-map unity-cxt)]
            [arduino-cxt (synth-map-arduino-context s-map)]
            [arduino-pre-state (symbolic-state arduino-cxt)]
            [arduino-st->unity-st (synth-map-arduino-state->unity-state s-map)]
            [unity-pre-environment (unity:environment*
                                    unity-cxt
                                    (arduino-st->unity-st arduino-pre-state))]
            [unity-post-environment (unity:interpret-assign
                                     unity-prog
                                     unity-pre-environment)])

       (define (try-synth cond-depth stmt-depth exp-depth)
         (let* ([start-time (current-seconds)]
                [sketch (cond-stmts?? cond-depth stmt-depth exp-depth arduino-cxt '())]
                [model (synthesize
                        #:forall
                        arduino-pre-state
                        #:guarantee
                        (assert
                         (let ([arduino-post-environment
                                (interpret-stmt sketch arduino-cxt arduino-pre-state)])
                           (and
                            (equal?
                             (environment*-context arduino-post-environment)
                             arduino-cxt)
                            (map-eq-modulo-keys-test-reference?
                             (keys unity-cxt)
                             (arduino-st->unity-st
                              (environment*-state arduino-post-environment))
                             (unity:environment*-state
                              unity-post-environment))))))])
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
                             (try-synth 1 1 (add1 exp-depth)))
                         (try-synth (add1 cond-depth) 1 exp-depth))
                     (try-synth cond-depth (add1 stmt-depth) exp-depth))))))

       (try-synth 1 1 0))]))

(provide synth-arduino-declare
         synth-arduino-setup
         synth-arduino-assign)
