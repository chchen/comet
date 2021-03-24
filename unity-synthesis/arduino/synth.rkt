#lang rosette/safe

(require "../environment.rkt"
         "../symbolic.rkt"
         "../synth.rkt"
         "../util.rkt"
         "inversion.rkt"
         "mapping.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in bb:"../bool-bitvec/synth.rkt")
         (prefix-in unity: "../unity/concretize.rkt")
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match)

(define (try-synth-expr synth-map postulate unity-val extra-snippets)
  (let* ([arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [val (unity:concretize-val unity-val postulate)]
         [val-ids (relevant-ids val arduino-st)]
         [snippets (match val
                     [(expression op args ...)
                      (if (in-list? op decomposable-ops)
                          (append
                           (flatten
                            (map (lambda (arg)
                                   (try-synth-expr synth-map postulate arg extra-snippets))
                                 args))
                           extra-snippets)
                          extra-snippets)]
                     [_ extra-snippets])])

    (define (try-synth exp-depth)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [sketch (exp-modulo-idents?? exp-depth arduino-cxt snippets val-ids)]
                [sketch-val (evaluate-expr sketch arduino-cxt arduino-st)]
                [expr-model (synthesize
                             #:forall arduino-st
                             #:guarantee (begin
                                           (assume postulate)
                                           (assert (eq? (if (boolean? val)
                                                            (bitvector->bool sketch-val)
                                                            sketch-val)
                                                        val))))])
           (if (sat? expr-model)
               (evaluate sketch expr-model)
               (if (>= exp-depth max-expression-depth)
                   expr-model
                   (try-synth (add1 exp-depth))))))))

    (try-synth 0)))

(define (unity-trace->memoized-arduino-stmts synth-map memos unity-guard unity-trace)
  (let* ([arduino-cxt (synth-map-target-context synth-map)]
         [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
         [arduino-st (synth-map-target-state synth-map)]
         [unity-st (arduino-st->unity-st arduino-st)]
         [memos-unordered-traces (bb:unity-trace->memoized-target-trace synth-map
                                                                        memos
                                                                        unity-guard
                                                                        unity-trace)])

    (define (trace-elem->stmt trace-elem)
      (let* ([id (car trace-elem)]
             [val (cdr trace-elem)]
             [id-typ (get-mapping id arduino-cxt)]
             [concrete-expr (try-synth-expr synth-map unity-guard val '())])
        (if (eq? id-typ 'pin-out)
            (write* id concrete-expr)
            (:=* id concrete-expr))))

    (define (try-fine-ordering unity-id arduino-stmts)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [sketch (ordering?? arduino-stmts)]
                [sketch-ok? (for/all ([s sketch])
                                     (monotonic-ok? unity-id
                                                    arduino-st
                                                    (environment*-state
                                                     (interpret-stmt (opaque-val s)
                                                                     arduino-cxt
                                                                     arduino-st))
                                                    unity-st
                                                    unity-trace
                                                    arduino-st->unity-st))]
                [order-model (synthesize
                        #:forall arduino-st
                        #:guarantee (begin
                                      (assume unity-guard)
                                      (assert sketch-ok?)))]
                [ordered-stmts (if (sat? order-model)
                                   (opaque-val (evaluate sketch order-model))
                                   order-model)])
           (begin
             (display (format "[try-fine-ordering] ~a ~a sec. ~a~n"
                              (sat? order-model)
                              (- (current-seconds) start-time)
                              ordered-stmts)
                      (current-error-port))
             ordered-stmts)))))

    (define (try-coarse-ordering arduino-traces arduino-stmts)
      (with-terms
        (vc-wrapper
         (let* ([start-time (current-seconds)]
                [reference-trace (apply append arduino-traces)]
                [sketch (ordering?? arduino-stmts)]
                [sketch-ok? (for/all ([s sketch])
                                     (map-eq-modulo-keys?
                                      (keys reference-trace)
                                      reference-trace
                                      (environment*-state
                                       (interpret-stmt (apply append (opaque-val s))
                                                       arduino-cxt
                                                       arduino-st))))]
                [order-model (synthesize
                        #:forall arduino-st
                        #:guarantee (begin
                                      (assume unity-guard)
                                      (assert sketch-ok?)))]
                [chosen-ordering (if (sat? order-model)
                                     (union-pick-head (evaluate sketch order-model))
                                     order-model)]
                [ordered-stmts (if (sat? order-model)
                                   (apply append
                                          (opaque-val chosen-ordering))
                                   order-model)])
           (begin
             (display (format "[try-coarse-ordering] ~a ~a sec. ~a~n"
                              (sat? order-model)
                              (- (current-seconds) start-time)
                              ordered-stmts)
                      (current-error-port))
             ordered-stmts)))))

    (if (eq? unity-trace unity-st)
        '()
        (let* ([new-trace (vc-wrapper (trim-trace unity-trace unity-st))]
               [unity-keys (map car new-trace)]
               [unity-values (map cdr new-trace)]
               [memos (car memos-unordered-traces)]
               [unordered-traces (cdr memos-unordered-traces)]
               [unordered-stmts (map (lambda (subtrace)
                                       (map trace-elem->stmt subtrace))
                                     unordered-traces)]
               [locally-ordered-stmts (map (lambda (k s)
                                             (if (in-list? k (synth-map-unity-external-vars synth-map))
                                                 (try-fine-ordering k s)
                                                 s))
                                           unity-keys unordered-stmts)])
          (cons memos
                (try-coarse-ordering unordered-traces locally-ordered-stmts))))))

(define (try-synth-decl context)
  (with-terms
    (vc-wrapper
     (if (null? context)
         '()
         (let* ([start-time (current-seconds)]
                [cxt-mapping (car context)]
                [decl-sketch (context-stmt?? cxt-mapping)]
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
                 (try-synth-decl (cdr context))))))))

(define (guarded-stmts->setup-stmt synth-map unity-initialize-st guarded-stmt)
  (let* ([start-time (current-seconds)]
         [arduino-cxt (synth-map-target-context synth-map)]
         ;; Synthesize declarations
         [declare-stmt (try-synth-decl (reverse arduino-cxt))]
         ;; Check declaration + initialization
         [setup-stmt (append declare-stmt
                             (guarded-stmt-stmt guarded-stmt))])
    (begin
      (display (format "[guarded-stmts->setup] ~a sec. ~a~n"
                       (- (current-seconds) start-time)
                       guarded-stmt)
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

(define (unity-guarded-traces->synth-stmts synth-map guarded-traces)
  (define (helper g-ts memos)
    (if (null? g-ts)
        '()
        (let* ([g-t (car g-ts)]
               [guard (guarded-trace-guard g-t)]
               [trace (guarded-trace-trace g-t)]
               [memoized-synth-stmt (unity-trace->memoized-arduino-stmts synth-map
                                                                         memos
                                                                         guard
                                                                         trace)])
          (cons (cdr memoized-synth-stmt)
                (helper (cdr g-ts)
                        (car memoized-synth-stmt))))))

  (helper guarded-traces '()))

(define (unity-guarded-trace->synth-stmt synth-map guarded-trace)
  (car (unity-guarded-traces->synth-stmts synth-map (list guarded-trace))))

(define (unity-guarded-trace->synth-guard synth-map guarded-tr assumptions)
  (let* ([start-time (current-seconds)]
         [guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard (try-synth-expr synth-map assumptions guard '())])
    (begin (display (format "[synth-guard] ~a sec. ~a~n"
                            (- (current-seconds) start-time)
                            synth-guard)
                    (current-error-port))
           synth-guard)))


(define (unity-prog->arduino-prog unity-prog)
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [synth-tr (unity-prog->synth-traces unity-prog synth-map)]
         [initially-state (unity-prog->initially-state unity-prog synth-map)]
         [assign-state (unity-prog->assign-state unity-prog synth-map)]
         [initially-guarded-trace (synth-traces-initially synth-tr)]
         [assign-guarded-traces (synth-traces-assign synth-tr)]
         [assign-guards (map guarded-trace-guard assign-guarded-traces)]
         [assign-guard-assumptions (guards->assumptions assign-guards)]
         [synth-guards (map (lambda (gd-tr gd-as)
                              (unity-guarded-trace->synth-guard synth-map
                                                                gd-tr
                                                                gd-as))
                            assign-guarded-traces
                            assign-guard-assumptions)]
         [synth-stmts (unity-guarded-traces->synth-stmts synth-map
                                                         assign-guarded-traces)]
         [assign-guarded-stmts (map (lambda (g s)
                                      (guarded-stmt g s))
                                    synth-guards
                                    synth-stmts)]
         [loop-stmt (guarded-stmts->if-stmt assign-guarded-stmts)]
         [initially-guarded-stmts (guarded-stmt #t
                                               (unity-guarded-trace->synth-stmt
                                                synth-map
                                                initially-guarded-trace))]
         [setup-stmt (guarded-stmts->setup-stmt synth-map initially-state initially-guarded-stmts)])
    (arduino*
     (setup* setup-stmt)
     (loop* loop-stmt))))

(provide unity-prog->arduino-prog)
