#lang rosette/safe

(require "../environment.rkt"
         "../synth.rkt"
         "../util.rkt"
         "../bool-bitvec/synth.rkt"
         "../bool-bitvec/types.rkt"
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
         rosette/lib/match)

(define decomposable-binops
  (append (list &&
                ||
                <=>)
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

(define (try-synth-expr synth-map postulate unity-val extra-snippets)
  (let* ([target-cxt (synth-map-target-context synth-map)]
         [target-st (synth-map-target-state synth-map)]
         [val (unity:concretize-val unity-val postulate)]
         [snippets (match val
                     [(expression op left right)
                      (if (in-list? op decomposable-binops)
                          (append (list (try-synth-expr synth-map postulate left extra-snippets)
                                        (try-synth-expr synth-map postulate right extra-snippets))
                                  extra-snippets)
                          extra-snippets)]
                     [(expression op expr)
                      (if (in-list? op decomposable-unops)
                          (append (list (try-synth-expr synth-map postulate expr extra-snippets))
                                  extra-snippets)
                          extra-snippets)]
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
                     #:guarantee (assert (eq? sketch-val val)))])
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

(define (target-trace->target-stmts synth-map guard trace snippets)
  (let ([target-cxt (synth-map-target-context synth-map)])

    (define (try-synth trace-elem)
      (let* ([id (car trace-elem)]
             [val (cdr trace-elem)]
             [expr (try-synth-expr synth-map guard val snippets)])
        (<=* id expr)))

    ;; Traces are "list-last", whereas statement ordering is
    ;; the opposite; reverse the order of statements so the output
    ;; matches the desired trace
    (reverse
     (map try-synth trace))))

(define (unity-guarded-trace->guarded-stmts synth-map guarded-tr snippets)
  (let* ([guard (guarded-trace-guard guarded-tr)]
         [trace (guarded-trace-trace guarded-tr)]
         [synth-guard
          (try-synth-expr synth-map #t guard snippets)]
         [synth-trace
          (unity-trace->target-trace synth-map guard trace)]
         [synth-stmts
          (target-trace->target-stmts
           synth-map guard synth-trace snippets)])
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
  (let* (;; [buf-preds (buffer-predicates unity-prog synth-map)]
         ;; [chan-preds (channel-predicates unity-prog synth-map)]
         ;; [preds (append buf-preds chan-preds)]
         [preds '()]
         [synth-traces (unity-prog->synth-traces unity-prog synth-map)]
         [initially-trace (synth-traces-initially synth-traces)]
         [assign-traces (synth-traces-assign synth-traces)]
         [initially-stmts (unity-guarded-trace->guarded-stmts synth-map
                                                              initially-trace
                                                              preds)]
         [assign-stmts (map
                        (lambda (gd-tr)
                          (unity-guarded-trace->guarded-stmts synth-map
                                                              gd-tr
                                                              preds))
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
