#lang rosette/safe

(require "../util.rkt"
         "buffer.rkt"
         "channel.rkt"
         "environment.rkt"
         "inversion.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match)

(define (try-synth-expr synth-map guard val snippets)
  (let* ([arduino-cxt (synth-map-arduino-context synth-map)]
         [arduino-st (synth-map-arduino-symbolic-state synth-map)])

    (define (try-synth exp-depth)
      (let* ([start-time (current-seconds)]
             [sketch (begin
                       (clear-asserts!)
                       (exp?? exp-depth arduino-cxt snippets))]
             [sketch-val (evaluate-expr sketch arduino-cxt arduino-st)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert guard)
                     #:guarantee (assert (eq? (if (boolean? val)
                                                  (bitvector->bool sketch-val)
                                                  sketch-val)
                                              val)))])
        (begin
          (display (format "[try-synth-expr] ~a ~a sec. depth: ~a ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           exp-depth
                           val)
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= exp-depth max-expression-depth)
                  model
                  (try-synth (add1 exp-depth)))))))

    (try-synth 0)))

(define (unity-trace->arduino-trace synth-map unity-guard unity-trace)
  (let* ([arduino-cxt (synth-map-arduino-context synth-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synth-map)]
         [unity-id->arduino-st->unity-val
          (synth-map-unity-id->arduino-state->unity-val synth-map)]
         [unity-id->arduino-ids (synth-map-unity-id->arduino-ids synth-map)]
         [arduino-st (synth-map-arduino-symbolic-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)])

    (define (trim-trace trace tail)
      (if (eq? trace tail)
          '()
          (cons (car trace)
                (trim-trace (cdr trace) tail))))

    (define (try-synth exp-depth unity-id unity-val)
      (let* ([start-time (current-seconds)]
             [arduino-ids (unity-id->arduino-ids unity-id)]
             [sketch-st (begin
                          (clear-asserts!)
                          (state?? arduino-ids exp-depth arduino-cxt arduino-st))]
             [mapped-val (unity-id->arduino-st->unity-val unity-id sketch-st)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert unity-guard)
                     #:guarantee (assert (eq? mapped-val unity-val)))])
        (begin
          (display (format "[unity-trace->arduino-trace] ~a ~a sec. depth: ~a ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           exp-depth
                           arduino-ids
                           unity-id)
                   (current-error-port))
          (if (sat? model)
              (trim-trace (evaluate sketch-st model)
                          arduino-st)
              (if (>= exp-depth max-expression-depth)
                  model
                  (try-synth (add1 exp-depth) unity-id unity-val))))))

     (if (eq? unity-trace unity-st)
         '()
         (foldr
          append
          '()
          (map (lambda (trace-el)
                 (try-synth 0 (car trace-el) (cdr trace-el)))
               (trim-trace unity-trace unity-st))))))

(define (arduino-trace->unordered-stmts synth-map guard trace snippets)
  (let ([arduino-cxt (synth-map-arduino-context synth-map)])

    (define (try-synth trace-elem)
      (let* ([id (car trace-elem)]
             [val (cdr trace-elem)]
             [id-typ (get-mapping id arduino-cxt)]
             [concrete-expr (try-synth-expr synth-map guard val snippets)])
        (if (eq? id-typ 'pin-out)
            (write* id concrete-expr)
            (:=* id concrete-expr))))

    (map try-synth trace)))

(define (unordered-stmts->ordered-stmts synth-map guard unity-trace unordered-stmts)
  (let* ([start-time (current-seconds)]
         [max-len (length unordered-stmts)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-arduino-context synth-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synth-map)]
         [arduino-st (synth-map-arduino-symbolic-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)])

    (define (try-synth len)
      (let* ([sketch (begin
                       (clear-asserts!)
                       (stmts?? len
                                unordered-stmts))]
             [arduino-post-env (interpret-stmt sketch arduino-cxt arduino-st)]
             [arduino-post-st (environment*-state arduino-post-env)]
             [post-st-eq? (map-eq-modulo-keys? all-vars
                                               (arduino-st->unity-st arduino-post-st)
                                               unity-trace)]
             [monotonic? (monotonic-pre-to-post? ext-vars
                                                 arduino-st
                                                 arduino-post-st
                                                 unity-st
                                                 unity-trace
                                                 arduino-st->unity-st)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert guard)
                     #:guarantee (assert (and post-st-eq? monotonic?)))])
        (begin
          (display (format "[unordered-stmts->ordered-stmts] ~a ~a sec. length: ~a ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           len
                           unordered-stmts)
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= len max-len)
                  model
                  (try-synth (add1 len)))))))

    (try-synth 0)))

(define (guarded-stmts->setup synth-map unity-post-st guarded-stmts)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]

         [arduino-cxt (synth-map-arduino-context synth-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synth-map)]
         [arduino-st (synth-map-arduino-symbolic-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]

         [cxt-sketch (begin
                       (clear-asserts!)
                       (context-stmts?? (length arduino-cxt) arduino-cxt))]
         [arduino-init-env (interpret-stmt cxt-sketch '() arduino-st)]
         [arduino-init-cxt (environment*-context arduino-init-env)]
         [arduino-init-st (environment*-state arduino-init-env)]

         [init-cxt-ok? (eq? arduino-init-cxt arduino-cxt)]
         [init-st-ok? (eq? arduino-init-st arduino-st)]
         [cxt-model (solve (assert (and init-cxt-ok? init-st-ok?)))]

         [st-sketch (guarded-stmt-stmt guarded-stmts)]
         [arduino-post-env (interpret-stmt st-sketch arduino-cxt arduino-st)]
         [arduino-post-cxt (environment*-context arduino-post-env)]
         [arduino-post-st (environment*-state arduino-post-env)]
         [context-ok? (eq? arduino-post-cxt arduino-cxt)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (arduino-st->unity-st arduino-post-st)
                                           unity-post-st)]
         [monotonic? (monotonic-pre-to-post? ext-vars
                                             arduino-st
                                             arduino-post-st
                                             unity-st
                                             unity-post-st
                                             arduino-st->unity-st)]
         [st-model (synthesize
                    #:forall arduino-st
                    #:guarantee (assert (and context-ok? post-st-eq? monotonic?)))]
         [model-sat? (and (sat? cxt-model)
                          (sat? st-model))])
    (begin
      (display (format "[guarded-stmts->setup] ~a ~a sec. ~a~n"
                       model-sat?
                       (- (current-seconds) start-time)
                       guarded-stmts)
               (current-error-port))
      (if model-sat?
          (append
           (evaluate cxt-sketch cxt-model)
           (evaluate st-sketch st-model))
          (list cxt-model st-model)))))

(define (guarded-stmts->loop synth-map unity-post-st guarded-stmts)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-arduino-context synth-map)]
         [arduino-st->unity-st (synth-map-arduino-state->unity-state synth-map)]
         [arduino-st (synth-map-arduino-symbolic-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [sketch (begin
                   (clear-asserts!)
                   (cond-stmts?? (length guarded-stmts) guarded-stmts))]
         [arduino-post-env (interpret-stmt sketch arduino-cxt arduino-st)]
         [arduino-post-cxt (environment*-context arduino-post-env)]
         [arduino-post-st (environment*-state arduino-post-env)]
         [context-ok? (eq? arduino-post-cxt
                           arduino-cxt)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (arduino-st->unity-st arduino-post-st)
                                           unity-post-st)]
         [monotonic? (monotonic-pre-to-post? ext-vars
                                             arduino-st
                                             arduino-post-st
                                             unity-st
                                             unity-post-st
                                             arduino-st->unity-st)]
         [model (synthesize
                 #:forall arduino-st
                 #:guarantee (assert (and context-ok? post-st-eq? monotonic?)))])
    (begin
      (display (format "[guarded-stmts->loop] ~a ~a sec. ~a~n"
                       (sat? model)
                       (- (current-seconds) start-time)
                       guarded-stmts)
               (current-error-port))
      (if (sat? model)
          (evaluate sketch model)
          model))))

(define (unity-guarded-trace->guarded-stmts synth-map guarded-tr snippets)
  (let* ([guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard
          (try-synth-expr synth-map #t guard snippets)]
         [synth-trace
          (unity-trace->arduino-trace synth-map guard trace)]
         [synth-unordered-stmts
          (arduino-trace->unordered-stmts
           synth-map guard synth-trace snippets)]
         [synth-ordered-stmts
          (unordered-stmts->ordered-stmts synth-map
                                          guard
                                          trace
                                          synth-unordered-stmts)])
    (guarded-stmt synth-guard
                  synth-ordered-stmts)))

(define (unity-prog->arduino-prog unity-prog)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [synth-tr (unity-prog->synth-traces unity-prog synth-map)]
         [initially-state (unity-prog->initially-state unity-prog synth-map)]
         [assign-state (unity-prog->assign-state unity-prog synth-map)]
         [buffer-preds (buffer-predicates unity-prog synth-map)]
         [channel-preds (channel-predicates unity-prog synth-map)]
         [preds (append buffer-preds
                        channel-preds)]
         [initially-guarded-trace (synth-traces-initially synth-tr)]
         [assign-guarded-traces (synth-traces-assign synth-tr)]
         [assign-guarded-stmts (map
                                (lambda (gd-tr)
                                  (unity-guarded-trace->guarded-stmts synth-map
                                                                      gd-tr
                                                                      preds))
                                assign-guarded-traces)]
         [loop-stmts (guarded-stmts->loop synth-map assign-state assign-guarded-stmts)]
         [initially-guarded-stmts (unity-guarded-trace->guarded-stmts synth-map
                                                                      initially-guarded-trace
                                                                      preds)]
         [setup-stmts (guarded-stmts->setup synth-map initially-state initially-guarded-stmts)])
    (arduino*
     (setup* setup-stmts)
     (loop* loop-stmts))))

(provide try-synth-expr
         unity-trace->arduino-trace
         arduino-trace->unordered-stmts
         unordered-stmts->ordered-stmts
         guarded-stmts->setup
         guarded-stmts->loop
         unity-guarded-trace->guarded-stmts
         unity-prog->arduino-prog)
