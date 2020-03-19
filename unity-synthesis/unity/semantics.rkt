#lang rosette

(require "../util.rkt"
         "environment.rkt"
         "syntax.rkt"
         rosette/lib/match)

(define (channel-empty? val)
  (and (channel*? val)
       (not (channel*-valid val))))

(define (channel-full? val)
  (and (channel*? val)
       (channel*-valid val)))

(define (eval-message val)
  (channel* #t val))

(define (eval-value val)
  (channel*-value val))

(define (eval-not v)
  (not v))

(define (eval-and l r)
  (and l r))

(define (eval-or l r)
  (or l r))

(define (eval-eq? l r)
  (eq? l r))

;; Evaluate an expression. Takes an expression, context, and a state
(define (evaluate-expr expression context state)
  (define (type-check? id val)
    (match (cxt-lookup id context)
      ['boolean (boolean? val)]
      ['channel (channel*? val)]
      [_ #f]))

  (define (unary-op predicate next-func expr error-symbol)
    (let ([val (eval-helper expr)])
      (if (predicate val)
          (next-func val)
          error-symbol)))
  
  (define (binary-op predicate next-func expr-l expr-r error-symbol)
    (let ([val-l (eval-helper expr-l)]
          [val-r (eval-helper expr-r)])
      (if (and (predicate val-l)
               (predicate val-r))
          (next-func val-l val-r)
          error-symbol)))

  (define (eval-helper expr)
    (match expr
      [(message* e) (unary-op boolean? eval-message e 'message-type-err)]
      [(value* c) (unary-op channel-full? channel*-value c 'value-type-err)]
      [(not* e) (unary-op boolean? eval-not e 'not-type-err)]
      [(and* l r) (binary-op boolean? eval-and l r 'and-type-err)]
      [(or* l r) (binary-op boolean? eval-or l r 'or-type-err)]
      [(eq?* l r) (binary-op boolean? eval-eq? l r 'eq-type-err)]
      [(full?* c) (unary-op channel*? channel*-valid c 'full-type-err)]
      [(empty?* c) (eval-helper (not* (full?* c)))]
      [term
       (cond
         ;; 'empty reserved word
         [(eq? term 'empty) (channel* #f null)]
         ;; boolean literals
         [(boolean? term) term]
         ;; all other symbols are variable references
         [(symbol? expr)
          (let ([val (state-get expr state)])
            (cond
              [(type-check? term val) val]
              [(null? val) 'null-reference]
              [else 'term-type-err]))]
         [else 'syntax-error])]))

  (eval-helper expression))

;; Interpret an assignment statement
;;
;; Apply the expression values to the corresponding variables, given a context
;; and start state. Expression values are with respect to the given start
;; state, not to any intermediate state.
;;
;; For conditional (case*) assignments, we apply the expression values if the
;; boolean expression guard is satisified. If no guards are satisified, then the
;; start state is returned.
(define (interpret-assign-stmt assignment context state)
  (define (apply-assignment l-var r-val next-func)
    (let* ([l-type (cxt-lookup l-var context)]
           [l-val (state-get l-var state)])
      (cond
        ;; propagate errors
        [(symbol? r-val) r-val]
        ;; bool := bool
        [(and (eq? l-type 'boolean)
              (boolean? r-val))
         next-func]
        ;; (undefined) channel := channel
        [(and (eq? l-type 'channel)
              (null? l-val)
              (channel*? r-val))
         next-func]
        ;; (full) channel := 'empty
        [(and (eq? l-type 'channel)
              (channel-full? l-val)
              (channel*? r-val)
              (not (channel*-valid r-val)))
         next-func]
        ;; (empty) channel := message
        [(and (eq? l-type 'channel)
              (channel-empty? l-val)
              (channel*? r-val)
              (channel*-valid r-val))
         next-func]
        [else 'assignment-type-err])))
  
  (define (filter-expressions exps-guards)
    (match exps-guards
      [(cons (cons exps guard) tail)
       (let ([guard-val (evaluate-expr guard context state)])
         (if (boolean? guard-val)
             (if guard-val exps (filter-expressions tail))
             'guard-type-err))]
      [_ '()]))

  (define (commit vars exps next-state)
    (if (and (pair? vars)
             (pair? exps))
        (let* ([var (car vars)]
               [expr (car exps)]
               [val (evaluate-expr expr context state)]
               [v-tail (cdr vars)]
               [e-tail (cdr exps)])
          (apply-assignment var
                            val
                            (commit v-tail
                                    e-tail
                                    (state-put var val next-state))))
          next-state))

    (match assignment
      [(:=* vars (case* exps-guards))
       (let ([exps (filter-expressions exps-guards)])
         (cond
           ;; propagate errors
           [(symbol? exps) exps]
           ;; no guards satisfied
           [(null? exps) state]
           [else (commit vars exps state)]))]
      [(:=* vars exps) (commit vars exps state)]))

;; Interpret the declaration clause. This just means taking adding the name to
;; type mapping and constructing a new environment
(define (interpret-declare program)
  (match program
    [(unity* (declare* type-declarations) _ _)
     (environment* type-declarations '())]))

(define (error-wrapper st f)
  (if (symbol? st)
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
         (interpret-assign-stmt initial-assignment cxt state)
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
         (interpret-assign-stmt (pick-stmt assign-statements) cxt state)
         (lambda (st)
           (environment* cxt st)))])]))

(provide evaluate-expr
         interpret-assign-stmt
         interpret-declare
         interpret-initially
         interpret-assign)

;; Test

(assert
 (let* ([prog
         (unity*
          (declare* (list (cons 'reg 'boolean)
                          (cons 'out 'channel)))
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
   (and (environment*? env)
        (environment*? env2)
        (environment*? env3))))
