#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         rosette/lib/match)

;; Evaluate an expression. Takes an expression and a state
(define (evaluate-expr expr state)
  (match expr
    [(message* e) (channel* #t (evaluate-expr e state))]
    [(value* c) (let ([c-val (evaluate-expr c state)])
                  (if (channel*-valid c-val)
                      (channel*-value c-val)
                      'error))]
    [(not* e) (not (evaluate-expr e state))]
    [(and* l r) (and (evaluate-expr l state)
                     (evaluate-expr r state))]
    [(or* l r) (or (evaluate-expr l state)
                   (evaluate-expr r state))]
    [(eq?* l r) (eq? (evaluate-expr l state)
                     (evaluate-expr r state))]
    [(full?* c) (channel*-valid (evaluate-expr c state))]
    [(empty?* c) (not (channel*-valid (evaluate-expr c state)))]
    [t (if (symbol? t)
           (match t
             ['empty (channel* #f null)]
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
  (define (assign-ok? lval rval)
    (if (eq? rval 'error)
        #f
        (match lval
          [(channel* #f _) (and (channel*? rval)
                                (channel*-valid rval))]
          [(channel* #t _) (and (channel*? rval)
                                (not (channel*-valid rval)))]
          [_ #t])))

  (define (filter-expressions exps-guards)
    (match exps-guards
      [(cons (cons exps guard) tail)
       (if (evaluate-expr guard state)
           exps
           (filter-expressions tail))]
      [_ '()]))

  (define (commit vars exps current-st next-st)
    (if (and (pair? vars)
             (pair? exps))
        (let* ([v (car vars)]
               [v-val (state-get v current-st)]
               [e (car exps)]
               [e-val (evaluate-expr e current-st)]
               [v-tail (cdr vars)]
               [e-tail (cdr exps)])
          (if (assign-ok? v-val e-val)
              (commit v-tail
                      e-tail
                      current-st
                      (state-put v
                                 e-val
                                 next-st))
              'error))
        next-st))

  (match assignment
    [(:=* vars (case* exps-guards))
     (let ([exps (filter-expressions exps-guards)])
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

(define (error-wrapper st f)
  (if (eq? st 'error)
      st
      (f st)))

;; Interpret the initially cause, given an existing environment with a context
;; and a state
(define (interpret-initially program env)
  (match program
    [(unity* _ (initially* initial-assignment) _)
     (match env
       [(environment* cxt state)
        (error-wrapper
         (interpret-assign-stmt initial-assignment state)
         (lambda (st)
           (environment* cxt st)))])]))

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
        (error-wrapper
         (interpret-assign-stmt (pick-stmt assign-statements) state)
         (lambda (st)
           (environment* cxt st)))])]))

(provide evaluate-expr
         interpret-declare
         interpret-initially
         interpret-assign)

;; Test

(let* ([prog
        (unity*
         (declare* (list (cons 'reg 'boolean)
                         (cons 'out 'channel-write)))
         (initially* (:=* (list 'reg
                                'out)
                          (list #f
                                'empty)))
         (assign* (list (:=* (list 'reg
                                   'out)
                             (case* (list (cons (list (not* 'reg)
                                                      (message* 'reg))
                                                (empty?* 'out))))))))]
       [env (interpret-declare prog)]
       [env2 (interpret-initially prog env)]
       [env3 (interpret-assign prog env2)])
  (assert
   (and (environment*? env)
        (environment*? env2)
        (environment*? env3))))
