#lang rosette

(require "syntax.rkt"
         "../util.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

;; Evaluation function for expressions
(define (eval exp env pins refs)
  (let ([varenv (car env)]
        [pinenv (append (cadr env) (cddr env))])
    (match exp
      [(and* a b) (and (eval a env pins refs) (eval b env pins refs))]
      [(or* a b) (or (eval a env pins refs) (eval b env pins refs))]
      [(eq* a b) (eq? (eval a env pins refs) (eval b env pins refs))]
      [(neq* a b) (not (eq? (eval a env pins refs) (eval b env pins refs)))]
      [(not* e) (not (eval e env pins refs))]
      [(read* p) (if (in-list? p pinenv)
                     (vector-ref pins p)
                     'typerr)]
      [(ref* v) (if (in-list? v varenv)
                    (vector-ref refs v)
                    'typerr)]
      [#t #t]
      [#f #f])))

(define-symbolic A B boolean?)

(let ([in-pins (list->vector (list A))]
      [in-refs (list->vector (list B))]
      [env (cons '(0)
                 (cons '(0) '()))])
  (assert (equal? (eval (not* (and* (read* 0) (ref* 0)))
                        env in-pins in-refs)
                  (eval (or* (not* (read* 0)) (not* (ref* 0)))
                        env in-pins in-refs))))

(define (update! vec key val)
  (vector-set! vec key val)
  vec)

;; Interpretation function for sequences of statements
(define (interpret prog env pins refs)
  (let ([varenv (car env)]
        [pinenv (cddr env)])
    (match prog
      [(seq* left right) (match left
                           [(write!* pin exp) (if (in-list? pin pinenv)
                                                  (interpret right
                                                             env
                                                             (update! pins pin (eval exp env pins refs))
                                                             refs)
                                                  'typerr)]
                           [(set!* var exp) (if (in-list? var varenv)
                                                (interpret right
                                                           env
                                                           pins
                                                           (update! refs var (eval exp env pins refs)))
                                                'typerr)]
                           [(if* exp btrue) (if (eval exp env pins refs)
                                                (let ([btrue-result (interpret btrue env pins refs)])
                                                  (interpret right env (car btrue-result) (cdr btrue-result)))
                                                (interpret right env pins refs))])]
      [_ (cons pins refs)])))

(assert (equal? (interpret (seq* (write!* 0 (ref* 0)) null)
                           (cons '(0)
                                 (cons '() '(0)))
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(B))
                      (list->vector '(B)))))

(assert (equal? (interpret (seq* (set!* 0 (read* 0)) null)
                           (cons '(0)
                                 (cons '(0) '()))
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(A)))))

(assert (equal? (interpret (seq* (if* #t
                                      (seq* (set!* 0 (read* 0)) null))
                                 null)
                           (cons '(0)
                                 (cons '(0) '()))
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(A)))))

(assert (equal? (interpret (seq* (if* #f
                                      (seq* (set!* 0 (read* 0)) null))
                                 null)
                           (cons '(0)
                                 (cons '(0) '()))
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(B)))))

(provide eval interpret)