#lang rosette

(require "syntax.rkt"
         "../util.rkt")

(define (reserved-symbol? symbol)
  (match symbol
    ['empty #t]
    ['unknown #t]
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

(define (channel-type? type)
  (match type
    ['channel-read #t]
    ['channel-write #t]
    [_ #f]))

(define (cxt-lookup id cxt)
  (match (assoc id cxt)
    [(cons _ type) type]
    [_ (error 'cxt-lookup "no type mapping for ~a in context ~a" id cxt)]))

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

;; Generic expression checker, takes an expression, a context, and a predicate
;; for allowable types
(define (expression-ok-helper? expr cxt term-type?)
  (match expr
    [(not* e) (expression-ok-helper? e cxt term-type?)]
    [(and* l r) (and (expression-ok-helper? l cxt term-type?)
                     (expression-ok-helper? r cxt term-type?))]
    [(or* l r) (and (expression-ok-helper? l cxt term-type?)
                    (expression-ok-helper? r cxt term-type?))]
    [(eq?* l r) (and (expression-ok-helper? l cxt term-type?)
                     (expression-ok-helper? r cxt term-type?))]
    [(full?* c) (channel-type? (cxt-lookup c cxt))]
    [(empty?* c) (channel-type? (cxt-lookup c cxt))]
    [t (if (symbol? t)
           (term-type? (cxt-lookup t cxt))
           (boolean? t))]))

;; Expression checker that allows terminals to be any valid type
(define (expression-ok? expr cxt)
  (expression-ok-helper? expr cxt valid-type?))

;; Expression checker that only allows channel terminals only over channel
;; predicates. Any other terminal must be a boolean
(define (guard-ok? expr cxt)
  (expression-ok-helper?
   expr
   cxt
   (lambda (type)
     (eq? 'boolean type))))

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
             ['boolean (expression-ok? e cxt)]
             ['channel-write (expression-ok? e cxt)]
             ['channel-read (eq? e 'empty)]
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
                      (guard-ok? guard cxt)
                      (vars-exps-ok? vars exps guard))]
                [_ #f]))
            #t
            exprs-guards)]
    [(:=* vars exps)
     (and (equal-length? vars exps)
          (vars-exps-ok? vars exps #t))]))

(expression-ok? (and* (full?* 'a) #f)
                (list (cons 'a 'channel-write)))

(assignment-ok?
 (:=* '(a b)
      '(b a))
 (list (cons 'a 'boolean)
       (cons 'b 'boolean)))

(assignment-ok?
 (:=* '(a b)
      (case* (list (cons '(#t a) (not* 'c)))))
 (list (cons 'a 'boolean)
       (cons 'b 'boolean)
       (cons 'c 'channel-read)))
