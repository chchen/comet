#lang rosette

(require "syntax.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

;; Evaluation function for expressions
(define (eval exp pins refs)
  (match exp
    [(and* a b) (and (eval a pins refs) (eval b pins refs))]
    [(or* a b) (or (eval a pins refs) (eval b pins refs))]
    [(eq* a b) (eq? (eval a pins refs) (eval b pins refs))]
    [(neq* a b) (not (eq? (eval a pins refs) (eval b pins refs)))]
    [(not* e) (not (eval e pins refs))]
    [(read* p) (vector-ref pins p)]
    [(ref* v) (vector-ref refs v)]
    [#t #t]
    [#f #f]))

(define-symbolic A B boolean?)

(let ([in-pins (list->vector (list A))]
      [in-refs (list->vector (list B))])
  (assert (equal? (eval (not* (and* (read* 0) (ref* 0)))
                        in-pins in-refs)
                  (eval (or* (not* (read* 0)) (not* (ref* 0)))
                        in-pins in-refs))))

(define (update! vec key val)
  (vector-set! vec key val)
  vec)

;; Interpretation function for sequences of statements
(define (interpret prog pins refs)
  (match prog
    [(seq* left right) (match left
                         [(write!* pin exp) (interpret right
                                                      (update! pins pin (eval exp pins refs))
                                                      refs)]
                         [(set!* var exp) (interpret right
                                                     pins
                                                     (update! refs var (eval exp pins refs)))]
                         [(if* exp btrue) (if (eval exp pins refs)
                                              (let ([btrue-result (interpret btrue pins refs)])
                                                (interpret right (car btrue-result) (cdr btrue-result)))
                                              (interpret right pins refs))])]
    [_ (cons pins refs)]))

(assert (equal? (interpret (seq* (write!* 0 (ref* 0)) null)
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(B))
                      (list->vector '(B)))))

(assert (equal? (interpret (seq* (set!* 0 (read* 0)) null)
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(A)))))

(assert (equal? (interpret (seq* (if* #t
                                      (seq* (set!* 0 (read* 0)) null))
                                 null)
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(A)))))

(assert (equal? (interpret (seq* (if* #f
                                      (seq* (set!* 0 (read* 0)) null))
                                 null)
                           (list->vector '(A))
                           (list->vector '(B)))
                (cons (list->vector '(A))
                      (list->vector '(B)))))

(provide eval interpret)