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
                          (begin (display (format "[try-synth-expr!] cannot decompose: ~a~n"
                                                  op)
                                          (current-error-port))
                                 extra-snippets))]
                     [_ extra-snippets])])

    (define (try-synth exp-depth)
      (let* ([start-time (current-seconds)]
             [val-type (cond
                         [(boolean? val) boolean?]
                         [(vect? val) vect?])]
             [sketch (begin
                       (clear-asserts!)
                       (exp?? exp-depth target-cxt val-type snippets))]
             [sketch-val (evaluate-expr sketch target-st)]
             [model (synthesize
                     #:forall target-st
                     #:assume (assert postulate)
                     #:guarantee (assert (eq? sketch-val val)))]
             [synth-expr (if (sat? model)
                             (evaluate sketch model)
                             model)])
        (begin
          (display (format "[try-synth-expr] ~a ~a sec. depth: ~a ~a -> ~a~n"
                           (sat? model)
                           (- (current-seconds) start-time)
                           exp-depth
                           val
                           synth-expr)
                   (current-error-port))
          (if (sat? model)
              synth-expr
              (if (>= exp-depth max-expression-depth)
                  synth-expr
                  (try-synth (add1 exp-depth)))))))

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

(define (unity-guarded-trace->guarded-stmts synth-map guarded-tr assumptions)
  (let* ([guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard
          (try-synth-expr synth-map assumptions guard '())]
         [synth-trace
          (unity-trace->target-trace synth-map assumptions guard trace)]
         [synth-stmts
          (target-trace->target-stmts synth-map guard synth-trace)])
    (guarded-stmt synth-guard
                  synth-stmts)))

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
         [initially-stmts (unity-guarded-trace->guarded-stmts synth-map
                                                              initially-trace
                                                              '())]
         [assign-stmts (map
                        (lambda (gd-tr gd-as)
                          (unity-guarded-trace->guarded-stmts synth-map
                                                              gd-tr
                                                              gd-as))
                        assign-traces
                        assign-guards-assumptions)])
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
  (let* ([synth-map (unity-prog->synth-map unity-prog)]
         [target-cxt (synth-map-target-context synth-map)]
         [port-list (verilog-context->port-list target-cxt)]
         [declarations (verilog-context->declarations target-cxt)]
         [always-block (unity-prog->always-block synth-map unity-prog)])
    (verilog-module* module-name
                     port-list
                     declarations
                     (list always-block))))

(provide try-synth-expr
         target-trace->target-stmts
         unity-guarded-trace->guarded-stmts
         unity-prog->always-block
         unity-prog->verilog-module)
