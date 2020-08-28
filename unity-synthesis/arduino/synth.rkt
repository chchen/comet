#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../util.rkt"
         "buffer.rkt"
         "channel.rkt"
         "inversion.rkt"
         "mapping.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/concretize.rkt")
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match
         ;; unsafe! bee careful
         (only-in racket/list permutations))

(define decomposable-binops
  (append (list &&
                ||)
          (list bvadd
                bvand
                bveq
                bvlshr
                bvor
                bvshl
                bvult
                bvxor)))

(define decomposable-unops
  (append (list !)
          (list bvnot)))


(define (try-synth-expr synth-map guard unity-val extra-snippets)
  (let* ([arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [val (unity:concretize-val unity-val guard)]
         [val-ids (relevant-ids val arduino-st)]
         [snippets (match val
                     [(expression op left right)
                      (if (in-list? op decomposable-binops)
                          (append (list (try-synth-expr synth-map guard left extra-snippets)
                                        (try-synth-expr synth-map guard right extra-snippets))
                                  extra-snippets)
                          extra-snippets)]
                     [(expression op expr)
                      (if (in-list? op decomposable-unops)
                          (append (list (try-synth-expr synth-map guard expr extra-snippets))
                                  extra-snippets)
                          extra-snippets)]
                     [_ extra-snippets])])

    (define (try-synth exp-depth)
      (let* ([start-time (current-seconds)]
             [sketch (begin
                       (clear-asserts!)
                       (exp-modulo-idents?? exp-depth arduino-cxt snippets val-ids))]
             [sketch-val (evaluate-expr sketch arduino-cxt arduino-st)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert guard)
                     #:guarantee (assert (eq? (if (boolean? val)
                                                  (bitvector->bool sketch-val)
                                                  sketch-val)
                                              val)))])
        (begin
          (display (format "[try-synth-expr] ~a ~a sec. depth: ~a ~a -> ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           exp-depth
                           val-ids
                           val
                           (if (sat? model)
                               (evaluate sketch model)
                               model))
                   (current-error-port))
          (if (sat? model)
              (evaluate sketch model)
              (if (>= exp-depth max-expression-depth)
                  model
                  (try-synth (add1 exp-depth)))))))

    (try-synth 0)))

(define (valid-trace-orderings trace state)
  (define (trace-ok? trace)
    (define (helper trace deps)
      (if (null? trace)
          #t
          (let* ([assignment (car trace)]
                 [l-val (car assignment)]
                 [r-val (cdr assignment)]
                 [l-symbolic (get-mapping l-val state)]
                 [r-symbolics (symbolics r-val)])
            (if (symbolic-in-list? l-symbolic deps)
                #f
                (helper (cdr trace)
                        (append r-symbolics
                                deps))))))

    (helper trace '()))

  (let* ([trace-orderings (permutations trace)]
         [all-suborderings (map prefixes trace-orderings)]
         [valid-traces (map (lambda (sublist)
                              (filter trace-ok? sublist))
                            all-suborderings)])
    (remove-duplicates
     (foldr append '() valid-traces))))

(define (trim-trace trace tail)
  (if (eq? trace tail)
      '()
      (cons (car trace)
            (trim-trace (cdr trace) tail))))

(define (unity-trace->arduino-traces synth-map assumptions unity-guard unity-trace)
  (let* ([arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [unity-id->arduino-st->unity-val
          (synth-map-unity-id->target-state->unity-val synth-map)]
         [unity-id->arduino-ids (synth-map-unity-id->target-ids synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)])

    (define (try-synth depth unity-id unity-val)
      (let* ([start-time (current-seconds)]
             [arduino-ids (unity-id->arduino-ids unity-id)]
             [arduino-id-vals (map (lambda (i)
                                     (get-mapping i arduino-st))
                                   arduino-ids)]
             [extra-arduino-st (filter (lambda (k-v)
                                         (not (member (car k-v) arduino-ids)))
                                       arduino-st)]
             [extra-arduino-vals (relevant-values unity-val
                                                  (map cdr extra-arduino-st))]
             [relevant-vals (append arduino-id-vals extra-arduino-vals)]
             [sketch-st (begin
                          (clear-asserts!)
                          (state?? arduino-ids relevant-vals depth arduino-cxt arduino-st))]
             [mapped-val (unity-id->arduino-st->unity-val unity-id sketch-st)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert (and assumptions
                                           unity-guard))
                     #:guarantee (assert (eq? mapped-val unity-val)))]
             [arduino-trace (if (sat? model)
                                    (trim-trace (evaluate sketch-st model)
                                                arduino-st)
                                    model)])
        (begin
          (display (format "[unity-trace->arduino-trace] ~a ~a sec. depth: ~a uid: ~a ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           depth
                           unity-id
                           relevant-vals
                           arduino-trace)
                   (current-error-port))
          (if (sat? model)
              (try-trim-ordering 0 arduino-trace unity-id unity-val)
              (if (>= depth max-expression-depth)
                  model
                  (try-synth (add1 depth) unity-id unity-val))))))

    (define (try-trim-ordering len synthesized-trace unity-id unity-val)
      (let* ([start-time (current-seconds)]
             [ext-vars (synth-map-unity-external-vars synth-map)]
             [valid-orderings (valid-trace-orderings synthesized-trace arduino-st)]
             [trace-ordering (begin
                               (clear-asserts!)
                               (ordering?? len synthesized-trace))]
             [sketch-st (append trace-ordering arduino-st)]
             [mapped-val (unity-id->arduino-st->unity-val unity-id sketch-st)]
             [post-st-eq? (eq? mapped-val unity-val)]
             [valid-ordering? (in-list? trace-ordering valid-orderings)]
             [monotonic? (if (in-list? unity-id ext-vars)
                             (monotonic-keys-ok? (list unity-id)
                                                 arduino-st
                                                 sketch-st
                                                 unity-st
                                                 unity-trace
                                                 arduino-st->unity-st)
                             #t)]
             [model (synthesize
                     #:forall arduino-st
                     #:assume (assert unity-guard)
                     #:guarantee (assert (and post-st-eq? valid-ordering? monotonic?)))]
             [ordered-trace (if (sat? model)
                                (evaluate trace-ordering model)
                                model)])
        (begin
          (display (format "[try-trim-ordering] ~a ~a sec. length: ~a ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           len
                           synthesized-trace
                           ordered-trace)
                   (current-error-port))
          (if (sat? model)
              ordered-trace
              (if (>= len (length synthesized-trace))
                  ordered-trace
                  (try-trim-ordering (add1 len) synthesized-trace unity-id unity-val))))))

    (if (eq? unity-trace unity-st)
        '()
        ;; Trimming may result in "no-op" traces. Exclude those.
        (filter pair?
                (map (lambda (trace-el)
                       (try-synth 0 (car trace-el) (cdr trace-el)))
                     (trim-trace unity-trace unity-st))))))

(define (arduino-traces->stmts synth-map guard traces snippets)
  (let ([arduino-cxt (synth-map-target-context synth-map)])

    (define (try-synth trace-elem)
      (let* ([id (car trace-elem)]
             [val (cdr trace-elem)]
             [id-typ (get-mapping id arduino-cxt)]
             [concrete-expr (try-synth-expr synth-map guard val snippets)])
        (if (eq? id-typ 'pin-out)
            (write* id concrete-expr)
            (:=* id concrete-expr))))

    (map (lambda (trace)
           ;; Ordering matters!
           ;; Statements are evaluated in order, but traces build like a stack
           ;; So equivalent statements are reversed with regards to their traces
           (reverse (map try-synth trace)))
         traces)))

(define (stmts->ordered-stmt synth-map guard unity-trace stmts)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [orderings (begin
                      (clear-asserts!)
                      (ordering?? (length stmts) stmts))]
         [sketch (flatten orderings)]
         [arduino-post-env (interpret-stmt sketch arduino-cxt arduino-st)]
         [arduino-post-st (environment*-state arduino-post-env)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (arduino-st->unity-st arduino-post-st)
                                           unity-trace)]
         [monotonic? (monotonic-keys-ok? ext-vars
                                         arduino-st
                                         arduino-post-st
                                         unity-st
                                         unity-trace
                                         arduino-st->unity-st)]
         [model (synthesize
                 #:forall arduino-st
                 #:assume (assert guard)
                 #:guarantee (assert (and post-st-eq? monotonic?)))]
         [ordered-stmt (if (sat? model)
                           (evaluate sketch model)
                           model)])
    (begin
      (display (format "[stmts->ordered-stmt] ~a ~a sec. ~a -> ~a~n"
                       (sat? model)
                       (- (current-seconds) start-time)
                       stmts
                       ordered-stmt)
               (current-error-port))
      ordered-stmt)))

(define (try-synth-decl context)
  (if (null? context)
      '()
      (let* ([start-time (current-seconds)]
             [cxt-mapping (car context)]
             [decl-sketch (begin
                            (clear-asserts!)
                            (context-stmt?? cxt-mapping))]
             [arduino-decl-env (interpret-stmt (list decl-sketch) '() '())]
             [arduino-decl-cxt (environment*-context arduino-decl-env)]
             [arduino-decl-st (environment*-state arduino-decl-env)]
             [cxt-ok? (eq? arduino-decl-cxt (list cxt-mapping))]
             [st-ok? (null? arduino-decl-st)]
             [decl-model (solve (assert (and cxt-ok? st-ok?)))]
             [synth-decl (if (sat? decl-model)
                             (evaluate decl-sketch decl-model)
                             '())])
        (cons synth-decl
              (try-synth-decl (cdr context))))))

(define (guarded-stmts->setup-stmt synth-map unity-initialize-st guarded-stmt)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-start-st (synth-map-target-state synth-map)]
         [unity-start-st (arduino-st->unity-st arduino-start-st)]
         ;; Synthesize declarations
         [declare-stmt (try-synth-decl (reverse arduino-cxt))]
         ;; Check declaration + initialization
         [initialize-stmt (append declare-stmt
                                  (guarded-stmt-stmt guarded-stmt))]
         [arduino-initialize-env (interpret-stmt initialize-stmt '() arduino-start-st)]
         [arduino-initialize-cxt (environment*-context arduino-initialize-env)]
         [arduino-initialize-st (environment*-state arduino-initialize-env)]
         [context-ok? (eq? arduino-initialize-cxt arduino-cxt)]
         [post-st-eq? (map-eq-modulo-keys? all-vars
                                           (arduino-st->unity-st arduino-initialize-st)
                                           unity-initialize-st)]
         [monotonic? (monotonic-keys-ok? ext-vars
                                         arduino-start-st
                                         arduino-initialize-st
                                         unity-start-st
                                         unity-initialize-st
                                         arduino-st->unity-st)]
         [initialize-model (verify
                            #:guarantee (assert (and context-ok?
                                                     post-st-eq?
                                                     monotonic?)))]
         [setup-stmt (if (unsat? initialize-model)
                         initialize-stmt
                         initialize-model)])
    (begin
      (display (format "[guarded-stmts->setup] ~a ~a sec. ~a -> ~a~n"
                       (unsat? initialize-model)
                       (- (current-seconds) start-time)
                       guarded-stmt
                       setup-stmt)
               (current-error-port))
      setup-stmt)))

(define (guarded-stmts->if-stmt guarded-stmts)
  (if (null? guarded-stmts)
      '()
      (let* ([guard (guarded-stmt-guard (car guarded-stmts))]
             [stmt (guarded-stmt-stmt (car guarded-stmts))])
        (cons (if* guard
                   stmt
                   (guarded-stmts->if-stmt (cdr guarded-stmts)))
              '()))))

(define (guarded-stmts->loop-stmt synth-map unity-post-st guarded-stmts)
  (let* ([start-time (current-seconds)]
         [ext-vars (synth-map-unity-external-vars synth-map)]
         [int-vars (synth-map-unity-internal-vars synth-map)]
         [all-vars (append ext-vars int-vars)]
         [arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [loop-stmt (guarded-stmts->if-stmt guarded-stmts)]
         [arduino-post-env (interpret-stmt loop-stmt arduino-cxt arduino-st)]
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
         [model (verify
                 #:guarantee (assert (and context-ok?
                                          post-st-eq?
                                          monotonic?)))])
    (begin
      (display (format "[guarded-stmts->loop] ~a ~a sec. ~a~n"
                       (unsat? model)
                       (- (current-seconds) start-time)
                       guarded-stmts)
               (current-error-port))
      (if (unsat? model)
          loop-stmt
          model))))

(define (unity-guarded-trace->guarded-stmt synth-map guarded-tr assumptions)
  (let* ([guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard (try-synth-expr synth-map assumptions guard '())]
         [synth-traces (unity-trace->arduino-traces synth-map assumptions guard trace)]
         [synth-stmts (arduino-traces->stmts synth-map guard synth-traces '())]
         [ordered-stmt (stmts->ordered-stmt synth-map guard trace synth-stmts)])
    (guarded-stmt synth-guard ordered-stmt)))

(define (unity-prog->arduino-prog unity-prog)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [synth-tr (unity-prog->synth-traces unity-prog synth-map)]
         [initially-state (unity-prog->initially-state unity-prog synth-map)]
         [assign-state (unity-prog->assign-state unity-prog synth-map)]
         [initially-guarded-trace (synth-traces-initially synth-tr)]
         [assign-guarded-traces (synth-traces-assign synth-tr)]
         [assign-guards (map guarded-trace-guard assign-guarded-traces)]
         [assign-guard-assumptions (guards->assumptions assign-guards)]
         [assign-guarded-stmt (map
                               (lambda (gd-tr gd-as)
                                 (unity-guarded-trace->guarded-stmt synth-map
                                                                    gd-tr
                                                                    gd-as))
                               assign-guarded-traces
                               assign-guard-assumptions)]
         [loop-stmt (guarded-stmts->loop-stmt synth-map assign-state assign-guarded-stmt)]
         [initially-guarded-stmt (unity-guarded-trace->guarded-stmt synth-map
                                                                    initially-guarded-trace
                                                                    #t)]
         [setup-stmt (guarded-stmts->setup-stmt synth-map initially-state initially-guarded-stmt)])
    (arduino*
     (setup* setup-stmt)
     (loop* loop-stmt))))

(provide unity-prog->arduino-prog)
