#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         rosette/lib/match)

;; The latest value of the variable id in the state store.
(define (state-get id state)
  (match (assoc id state)
    [(cons _ val) val]
    [_ (error 'state-get "no mapping for ~a in state store ~a" id state)]))

;; Adds a new value mapping for variable id in the state store
(define (state-put id val state)
  (cons (cons id val) state))

;; Evaluate a boolean expression. Takes an expression and a state
(define (evaluate expression state)
  (match expression
    [(not* e) (not (evaluate e state))]
    [(and* l r) (and (evaluate l state)
                     (evaluate r state))]
    [(or* l r) (or (evaluate l state)
                   (evaluate r state))]
    [(eq?* l r) (eq? (evaluate l state)
                     (evaluate r state))]
    ['empty 'empty]
    [#t #t]
    [#f #f]
    [v (state-get v state)]))

;; Interpret an assignment statement
;;
;; Apply the expression values to the corresponding variables, given a start
;; state. Expression values are with respect to the given start state, not to
;; any intermediate state.
;;
;; For conditional (case*) assignments, we apply the expression values if the
;; boolean expression guard is satisified. If no guards are satisified, then the
;; start state is returned.
(define (interpret-assign-stmt assignment state)
  (define (filter-expressions cond-exps state)
    (match cond-exps
      [(cons (cons exps guard) tail)
       (if (evaluate guard state)
           exps
           (filter-expressions tail state))]
      [_ '()]))

  (define (commit vars exps from-st to-st)
    (if (and (pair? vars)
             (pair? exps))
        (let ([v (car vars)]
              [e (car exps)]
              [v-tail (cdr vars)]
              [e-tail (cdr exps)])
          (commit v-tail
                  e-tail
                  from-st
                  (state-put v
                             (evaluate e from-st)
                             to-st)))
        to-st))

  (match assignment
    [(:=* vars (case* cond-exps))
    (let ([exps (filter-expressions cond-exps state)])
       (if (null? exps)
           state
           (commit vars exps state state)))]
    [(:=* vars exps)
     (commit vars exps state state)]))

;; Interpret the declaration clause. This just means taking adding the name to
;; type mapping and constructing a new environment
(define (interpret-declare program)
  (match program
    [(unity* (declare* type-declarations) _ _)
     (environment* type-declarations '())]))

;; Interpret the initially cause, given an existing environment with a context
;; and a state
(define (interpret-initially program env)
  (match program
    [(unity* _ (initially* initial-assignment) _)
     (match env
       [(environment* cxt state)
        (environment* cxt
                      (interpret-assign-stmt initial-assignment
                                             state))])]))

;; Interpret the assign clause, given an existing environment with a context and
;; a state
(define (interpret-assign program env)
  (define (pick-stmt stmts)
    (list-ref stmts (random (length stmts))))

  (match program
    [(unity* _ _ (assign* '())) env]
    [(unity* _ _ (assign* assign-statements))
     (match env
       [(environment* cxt state)
        (environment* cxt
                      (interpret-assign-stmt
                       (pick-stmt assign-statements)
                       state))])]))

(provide state-get
         evaluate
         interpret-declare
         interpret-initially
         interpret-assign)

;; Sample Program

;; (unity* (declare* (list (cons 'reg 'boolean)
;;                         (cons 'out 'channel-write)))
;;         (initially* (:=* (list 'reg 'out)
;;                          (list #f 'empty)))
;;         (assign* (list (:=* (list 'out)
;;                             (list 'reg)))))
