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

;; Check if expression types to a boolean in a context
(define (boolean-expression? expr cxt)
  (match expr
    [(not* e) (boolean-expression? e cxt)]
    [(and* l r) (and (boolean-expression? l cxt)
                     (boolean-expression? r cxt))]
    [(or* l r) (and (boolean-expression? l cxt)
                    (boolean-expression? r cxt))]
    [(eq?* l r) (and (boolean-expression? l cxt)
                     (boolean-expression? r cxt))]
    [(full?* c) (channel-type? (cxt-lookup c cxt))]
    [(empty?* c) (channel-type? (cxt-lookup c cxt))]
    [t (if (symbol? t)
           (valid-type? (cxt-lookup t cxt))
           (boolean? t))]))

(define (assignment-ok? assignment cxt)
  (define (extract-expressions cond-exps)
    (map car cond-exps))

  (define (vars-exps-ok? vars exps)
    (if (and (pair? vars)
             (pair? exps))
        (let* ([v (car vars)]
               [v-type (cxt-lookup v cxt)]
               [e (car exps)]
               [v-tail (cdr vars)]
               [e-tail (cdr exps)])
          (and
           (match v-type
             ['boolean (boolean-expression? e cxt)]
             ['channel-write (boolean-expression? e cxt)]
             ['channel-read (eq? e 'empty)]
             [_ (error "oops")])
           (vars-exps-ok? v-tail e-tail)))
        #t))

  (match assignment
    [(:=* vars (case* cond-exps))
     (foldl (lambda (exps ok)
              (and ok
                   (equal-length? vars exps)
                   (vars-exps-ok? vars exps)))
            #t
            (extract-expressions cond-exps))]
    [(:=* vars exps)
     (and (equal-length? vars exps)
          (vars-exps-ok? vars exps))]))

(boolean-expression? (and* (full?* 'a) #f) (list (cons 'a 'channel-write)))

(assignment-ok?
 (:=* '(a b)
      '(b a))
 (list (cons 'a 'boolean)
       (cons 'b 'boolean)))

(assignment-ok?
 (:=* '(a b)
      (case* (list (cons '(#t #f) #t)
                   (cons '(#t 'a) #f))))
 (list (cons 'a 'boolean)
       (cons 'b 'boolean)))
