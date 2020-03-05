#lang rosette

(require "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/match)

(define (reserved-symbol? symbol)
  (match symbol
    ['empty #t]
    ['error #t]
    [_ #f]))

(define (valid-identifier? id)
  (and (symbol? id)
       (not (reserved-symbol? id))))

(define (valid-type? type)
  (match type
    ['boolean #t]
    ['channel-read #t]
    ['channel-write #t]
    [_ #f]))

;; Validate a declaration clause. Each pair if (id, type) must be a valid id
;; (not a reserved symbol, valid type) and each id should be declared only once
(define (declare-ok? declarations)
  (define (check decl processed)
    (match decl
      ['() #t]
      [(cons (cons id type) tail)
       (and (valid-identifier? id)
            (valid-type? type)
            (not (in-list? id processed))
            (check tail (cons id processed)))]))

  (and (list? declarations)
       (check declarations '())))

;; ¡Construct a symbolic state!
(define (symbolic-state cxt)
  (define (symbolic-boolean)
    (define-symbolic* x boolean?)
    x)

  (match cxt
    ['() '()]
    [(cons (cons x 'boolean) tail)
     (cons (cons x (symbolic-boolean))
           (symbolic-state tail))]
    [(cons (cons x 'channel-write) tail)
     (cons (cons x (channel* (symbolic-boolean)
                             (symbolic-boolean)))
           (symbolic-state tail))]
    [(cons (cons x 'channel-read) tail)
     (cons (cons x (channel* (symbolic-boolean)
                             (symbolic-boolean)))
           (symbolic-state tail))]))

(define (boolean-under-guard? expr guard cxt)
  (let* ([state (symbolic-state cxt)]
         [model
          (verify
           #:assume
           (assert (evaluate-expr guard state))
           #:guarantee
           (assert (boolean? (evaluate-expr expr state))))])
    (if (eq? (unsat) model)
        #t
        (error 'expr-guard-check "counterexample ~a" (evaluate state model)))))

;; Generic expression checker, takes an expression, a context, and a predicate
;; for allowable types
(define (guarded-expression-ok? expr cxt type guard)
  (define (subtree-ok? expr type)
    (match expr
      [(message* e) (and (eq? type 'channel-write)
                         (subtree-ok? e 'boolean))]
      [(value* c) (and (eq? type 'boolean)
                       (boolean-under-guard? expr guard cxt)
                       (subtree-ok? c 'channel-read))]
      [(not* e) (and (eq? type 'boolean)
                     (subtree-ok? e 'boolean))]
      [(and* l r) (and (eq? type 'boolean)
                       (subtree-ok? l 'boolean)
                       (subtree-ok? r 'boolean))]
      [(or* l r) (and (eq? type 'boolean)
                      (subtree-ok? l 'boolean)
                      (subtree-ok? r 'boolean))]
      [(eq?* l r) (and (eq? type 'boolean)
                       (subtree-ok? l 'boolean)
                       (subtree-ok? r 'boolean))]
      [(full?* c) (and (eq? type 'boolean)
                       (subtree-ok? c 'channel-read))]
      [(empty?* c) (and (eq? type 'boolean)
                        (subtree-ok? c 'channel-write))]
      [t (cond
           [(boolean? t)
            (eq? type 'boolean)]
           [(eq? t 'empty)
            (eq? type 'channel-write)]
           [(symbol? t)
            (eq? type (cxt-lookup t cxt))]
           [else #f])]))

  (subtree-ok? expr type))

(define (expression-ok? expr cxt type)
  (guarded-expression-ok? expr cxt type #t))

(define (assignment-ok? assignment cxt)
  (define (vars-exps-ok? vars exps guard)
    (if (and (pair? vars)
             (pair? exps))
        (let* ([v (car vars)]
               [v-type (cxt-lookup v cxt)]
               [e (car exps)]
               [v-tail (cdr vars)]
               [e-tail (cdr exps)])
            (and
             (match v-type
               ['boolean (guarded-expression-ok? e cxt 'boolean guard)]
               ['channel-write (guarded-expression-ok? e cxt 'channel-write guard)]
               ['channel-read (guarded-expression-ok? e cxt 'channel-read guard)]
               [_ (error "oops")])
             (vars-exps-ok? v-tail e-tail guard)))
        #t))

  (match assignment
    [(:=* vars (case* exprs-guards))
     (foldl (lambda (exps-guard ok)
              (match exps-guard
                [(cons exps guard)
                 (and ok
                      (equal-length? vars exps)
                      (expression-ok? guard cxt 'boolean)
                      (vars-exps-ok? vars exps guard))]
                [_ #f]))
            #t
            exprs-guards)]
    [(:=* vars exps)
     (and (equal-length? vars exps)
          (vars-exps-ok? vars exps #t))]))

;; Hello tests
(assert (expression-ok? (and* (full?* 'a) #f)
                        (list (cons 'a 'channel-read))
                        'boolean))

(assert (guarded-expression-ok? (value* 'a)
                                (list (cons 'a 'channel-read))
                                'boolean
                                (full?* 'a)))

(assert (assignment-ok?
         (:=* '(a b)
              '(b a))
         (list (cons 'a 'boolean)
               (cons 'b 'boolean))))

(assert (assignment-ok?
         (:=* '(a b)
              (case* (list (cons (list #t 'a)
                                 (empty?* 'c)))))
         (list (cons 'a 'boolean)
               (cons 'b 'boolean)
               (cons 'c 'channel-write))))

(assert (expression-ok? (full?* 'c)
                        (list (cons 'a 'boolean)
                              (cons 'c 'channel-read))
                        'boolean))

(assert (assignment-ok?
         (:=* (list 'a)
              (case* (list (cons (list (value* 'c))
                                 (full?* 'c)))))
         (list (cons 'a 'boolean)
               (cons 'c 'channel-read))))
