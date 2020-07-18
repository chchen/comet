#lang rosette/safe

(require "../environment.rkt"
         "../util.rkt"
         "../bool-bitvec/types.rkt"
         "syntax.rkt"
         rosette/lib/match)

(define (width? mapping width)
  (define (ok? w)
    (eq? w width))

  (ok?
   (match (cdr mapping)
     [(port-decl* t-d) (type-decl*-width t-d)]
     [(type-decl* w _) w])))

(define (bool-typ? mapping)
  (width? mapping 1))

(define (vect-typ? mapping)
  (width? mapping vect-len))

;; Build a verilog context from a program's preamble
(define (preamble->context decls)
  (define (decl->mapping decl)
    (match decl
      [(port-decl* typ) (cons (type-decl*-ident typ) decl)]
      [(type-decl* _ ident) (cons ident decl)]))

  (map decl->mapping decls))

;; Evaluate an expression that yields a value
(define (evaluate-expr expr state)
  (match expr
    ;; Unary
    [(unop* l)
     (let ([l-val (evaluate-expr l state)])
       (match expr
         ;; bool -> vector conversion
         [(bool->vect* _) (bool->vect l-val)]
         ;; bool -> bool
         [(posedge* _) (eq? l-val #t)]
         [(negedge* _) (eq? l-val #f)]
         [(not* _) (not l-val)]
         ;; vector -> vector
         [(bwnot* _) (bvnot l-val)]))]
    [(binop* l r)
     (let ([l-val (evaluate-expr l state)]
           [r-val (evaluate-expr r state)])
       (match expr
         ;; bool -> bool -> bool
         [(and* _ _) (and l-val r-val)]
         [(or* _ _) (or l-val r-val)]
         [(eq* _ _) (eq? l-val r-val)]
         ;; vector -> vector -> bool
         [(bweq* _ _) (bveq l-val r-val)]
         [(lt* _ _) (bvult l-val r-val)]
         ;; vector -> vector -> vector
         [(bwand* _ _) (bvand l-val r-val)]
         [(bwor* _ _) (bvor l-val r-val)]
         [(bwxor* _ _) (bvxor l-val r-val)]
         [(shl* _ _) (bvshl l-val r-val)]
         [(shr* _ _) (bvlshr l-val r-val)]
         [(add* _ _) (bvadd l-val r-val)]))]
    [e (cond
         [(boolean? e) e]
         [(vect? e) e]
         [else (get-mapping e state)])]))

;; Interpret a sequence of statements whose assignments
;; appear as atomic updates from some previous state
;; to a next state
(define (interpret-stmts statements state)
  (define (helper stmts next-state)
    (match stmts
      ['() next-state]
      [(cons stmt tail)
       (match stmt
         [(always* guard branch)
          (let* ([guard-val (evaluate-expr guard state)]
                 [always-state (if guard-val (helper branch next-state) next-state)])
            (helper tail always-state))]
         [(if* guard branch-t branch-f)
          (let* ([guard-val (evaluate-expr guard state)]
                 [branch-chosen (if guard-val branch-t branch-f)]
                 [if-state (helper branch-chosen next-state)])
            (helper tail if-state))]
         [(<=* l r)
          (let* ([r-val (evaluate-expr r state)])
            (helper tail (add-mapping l r-val next-state)))])]))

  (helper statements state))


;; Interpret a module given context, state, and list of triggering events
(define (interpret-module verilog-module environment)
  (match environment
    [(environment* context state)
     (match verilog-module
       [(verilog-module* _ _ declarations assignments)
        (environment* (preamble->context declarations)
                      (interpret-stmts assignments state))])]))

(define (interpret-module-reset verilog-module environment)
  (match environment
    [(environment* context state)
     (interpret-module verilog-module
                       (environment* context
                                     (cons (cons 'reset #t)
                                           state)))]))

(define (interpret-module-clock verilog-module environment)
  (match environment
    [(environment* context state)
     (interpret-module verilog-module
                       (environment* context
                                     (append (list (cons 'reset #f)
                                                   (cons 'clock #t))
                                             state)))]))

(provide bool-typ?
         vect-typ?
         preamble->context
         evaluate-expr
         interpret-stmts
         interpret-module
         interpret-module-reset
         interpret-module-clock)

;; Tests

(define-symbolic A B C D boolean?)

;; Quick check: De Morgan on an expression
(let* ([state (list (cons 'a A)
                    (cons 'b B))])
  (assert
   (unsat?
    (verify
     (assert
      (eq? (evaluate-expr (not* (and* 'a 'b))
                          state)
           (evaluate-expr (or* (not* 'a)
                               (not* 'b))
                          state)))))))

(assert (evaluate-expr (posedge* 'clk) (list (cons 'clk #t))))
(assert (evaluate-expr (negedge* 'reset) (list (cons 'reset #f))))
(assert (not (evaluate-expr (negedge* 'clk) '())))

;; Quick check: assign input value to output conditionally
(let* ([start-st (list (cons 'clk #f)
                       (cons 'input A)
                       (cons 'output B)
                       (cons 'guard C)
                       (cons 'internal D))]
       [end-st (interpret-stmts (list
                                 (always* (negedge* 'clk)
                                          (list (if* 'guard
                                                     (list (<=* 'output 'input))
                                                     (list (<=* 'output (not* 'input))))
                                                (<=* 'internal (not* 'internal)))))
                                start-st)]
       [guard-val (get-mapping 'guard start-st)]
       [input-val (get-mapping 'input start-st)]
       [output-val (get-mapping 'output end-st)]
       [internal-val-pre (get-mapping 'internal start-st)]
       [internal-val-post (get-mapping 'internal end-st)])
  (assert
   (unsat?
    (verify
     (assert
      (and (eq? output-val
                (if guard-val input-val (not input-val)))
           (eq? internal-val-post
                (not internal-val-pre))))))))

;; Quick check: fifo on clock tick
(let* ([test
        (verilog-module*
         'test
         (list 'in 'out 'clock 'reset)
         (list (input* (wire* 1 'in))
               (output* (reg* 1 'out))
               (input* (wire* 1 'clock))
               (input* (wire* 1 'reset)))
         (list (always* (or* (posedge* 'clock)
                             (posedge* 'reset))
                        (list (if* 'reset
                                   (list (<=* 'out #f))
                                   (list (<=* 'out 'in)))))))]
       [start-st (list (cons 'in A)
                       (cons 'out B))]
       [reset-st (append (list (cons 'reset #t)
                               (cons 'clock #f))
                         start-st)]
       [clock-st (append (list (cons 'reset #f)
                               (cons 'clock #t))
                         start-st)]
       [noop-env (interpret-module test (environment* '() start-st))]
       [reset-env (interpret-module test (environment* '() reset-st))]
       [clock-env (interpret-module test (environment* '() clock-st))]
       [noop-post (environment*-state noop-env)]
       [reset-post (environment*-state reset-env)]
       [clock-post (environment*-state clock-env)])
  (assert
   (unsat?
    (verify
     (assert
      (and (eq? start-st noop-post)
           (eq? (get-mapping 'out reset-post) #f)
           (eq? (get-mapping 'out clock-post)
                (get-mapping 'in start-st))))))))
