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
(define (evaluate expr state)
  (match expr
    [(message* e) (channel* #t (evaluate e state))]
    [(value* c) (channel*-value (evaluate c state))]
    [(not* e) (not (evaluate e state))]
    [(and* l r) (and (evaluate l state)
                     (evaluate r state))]
    [(or* l r) (or (evaluate l state)
                   (evaluate r state))]
    [(eq?* l r) (eq? (evaluate l state)
                     (evaluate r state))]
    [(full?* c) (channel*-valid (evaluate c state))]
    [(empty?* c) (not (channel*-valid (evaluate c state)))]
    [t (if (symbol? t)
           (match t
             ['empty (channel* #f 'inaccessible)]
             [_ (state-get t state)])
           t)]))

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
  (define (filter-expressions exps-guards state)
    (match exps-guards
      [(cons (cons exps guard) tail)
       (if (evaluate guard state)
           exps
           (filter-expressions tail state))]
      [_ '()]))

  (define (commit vars exps current-st next-st)
    (if (and (pair? vars)
             (pair? exps))
        (let ([v (car vars)]
              [e (car exps)]
              [v-tail (cdr vars)]
              [e-tail (cdr exps)])
          (commit v-tail
                  e-tail
                  current-st
                 (state-put v
                             (evaluate e current-st)
                             next-st)))
        next-st))

  (match assignment
    [(:=* vars (case* exps-guards))
     (let ([exps (filter-expressions exps-guards state)])
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

;; (let* ([prog
;;        (unity*
;;         (declare* (list (cons 'reg 'boolean)
;;                         (cons 'out 'channel-write)))
;;         (initially* (:=* (list 'reg
;;                                'out)
;;                          (list #f
;;                                'empty)))
;;         (assign* (list (:=* (list 'reg
;;                                   'out)
;;                             (case* (list (cons (list (not* 'reg)
;;                                                      (message* 'reg))
;;                                                (empty?* 'out))))))))]
;;        [env (interpret-declare prog)]
;;        [env2 (interpret-initially prog env)]
;;        [env3 (interpret-assign prog env2)])
;;   (list env env2 env3))
