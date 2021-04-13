#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../util.rkt"
         "../bool-bitvec/synth.rkt"
         "../bool-bitvec/types.rkt"
         "inversion.rkt"
         "mapping.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/concretize.rkt")
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match)

(define (try-synth-expr synth-map postulate unity-val extra-snippets)
  (let* ([target-cxt (synth-map-target-context synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [val (unity:concretize-val unity-val postulate)]
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
                [val-type (cond
                            [(boolean? val) boolean?]
                            [(vect? val) vect?])]
                [sketch (exp?? exp-depth target-cxt val-type snippets)]
                [sketch-val (evaluate-expr sketch target-st)]
                [model (synthesize
                        #:forall target-st
                        #:guarantee (begin (assume postulate)
                                           (assert (eq? sketch-val val))))]
                [synth-expr (if (sat? model)
                                (evaluate sketch model)
                                model)])
           (if (sat? model)
               synth-expr
               (if (>= exp-depth max-expression-depth)
                   synth-expr
                   (try-synth (add1 exp-depth))))))))

    (try-synth 0)))

(define (target-trace->target-stmts synth-map guard trace)
  (let ([target-cxt (synth-map-target-context synth-map)])

    (define (try-synth trace-elem)
      (let* ([id (car trace-elem)]
             [val (cdr trace-elem)]
             [expr (try-synth-expr synth-map guard val '())])
        (<=* id expr)))

    ;; Traces are "list-last", whereas statement ordering is
    ;; the opposite; reverse the order of statements so the output
    ;; matches the desired trace
    (reverse
     (map try-synth trace))))

(define (unity-guarded-trace->guarded-stmt synth-map assumptions guarded-tr)
  (let* ([guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard (try-synth-expr synth-map assumptions guard '())]
         [memoized-synth-trace
          (unity-trace->memoized-target-trace synth-map '() guard trace)]
         [synth-trace (apply append (cdr memoized-synth-trace))]
         [synth-stmts (target-trace->target-stmts synth-map guard synth-trace)])
    (guarded-stmt synth-guard
                  synth-stmts)))

(define (unity-guarded-traces->guarded-stmts synth-map guard-assumptions guarded-trs)
  (define (helper g-trs g-ass memos)
    (if (null? g-trs)
        '()
        (let* ([guarded-tr (car g-trs)]
               [assumptions (car g-ass)]
               [guard (guarded-trace-guard guarded-tr)]
               [trace (guarded-trace-trace guarded-tr)]
               [synth-guard (try-synth-expr synth-map assumptions guard '())]
               [memoized-synth-trace
                (unity-trace->memoized-target-trace synth-map memos guard trace)]
               [synth-trace (apply append (cdr memoized-synth-trace))]
               [synth-stmts (target-trace->target-stmts synth-map guard synth-trace)])
          (cons (guarded-stmt synth-guard
                              synth-stmts)
                (helper (cdr g-trs)
                        (cdr g-ass)
                        (car memoized-synth-trace))))))

  (helper guarded-trs guard-assumptions '()))

(define (guarded-stmts->conditional-stmts guarded-stmts)
  (if (null? guarded-stmts)
      '()
      (let* ([gd-st (car guarded-stmts)]
             [tail (cdr guarded-stmts)]
             [guard (guarded-stmt-guard gd-st)]
             [stmts (guarded-stmt-stmt gd-st)])
        (list (if* guard
                   stmts
                   (guarded-stmts->conditional-stmts tail))))))

(define (unity-prog->always-block synth-map unity-prog)
  (let* ([synth-traces (unity-prog->synth-traces unity-prog synth-map)]
         [initially-trace (synth-traces-initially synth-traces)]
         [assign-traces (synth-traces-assign synth-traces)]
         [assign-guards (map guarded-trace-guard assign-traces)]
         [assign-guards-assumptions (guards->assumptions assign-guards)]
         [check (begin (display (format "[pre-synth vc] vc: ~a~n" (vc))
                                (current-error-port))
                       #t)]
         [initially-stmts (unity-guarded-trace->guarded-stmt synth-map
                                                              '()
                                                              initially-trace)]
         [assign-stmts (unity-guarded-traces->guarded-stmts synth-map
                                                            assign-guards-assumptions
                                                            assign-traces)])
    (always* (or* (posedge* 'clock)
                  (posedge* 'reset))
             (list (if* 'reset
                        (guarded-stmt-stmt initially-stmts)
                        (guarded-stmts->conditional-stmts assign-stmts))))))

(define (verilog-context->declarations cxt)
  (map cdr cxt))

(define (verilog-context->port-list cxt)
  (define (port? mapping)
    (match (cdr mapping)
      [(port-decl* _) #t]
      [_ #f]))

  (map car
       (filter port? cxt)))

(define (unity-prog->verilog-module unity-prog module-name)
  (let* ([start-time (current-seconds)]
         [synth-map (unity-prog->synth-map unity-prog)]
         [target-cxt (synth-map-target-context synth-map)]
         [port-list (verilog-context->port-list target-cxt)]
         [declarations (verilog-context->declarations target-cxt)]
         [always-block (unity-prog->always-block synth-map unity-prog)])
    (begin
      (display (format "[unity-prog->verilog-module] ~a sec.~n"
                       (- (current-seconds) start-time))
               (current-error-port))
      (verilog-module* module-name
                       port-list
                       declarations
                       (list always-block)))))

(provide try-synth-expr
         target-trace->target-stmts
         unity-guarded-trace->guarded-stmt
         unity-guarded-traces->guarded-stmts
         unity-prog->always-block
         unity-prog->verilog-module)
