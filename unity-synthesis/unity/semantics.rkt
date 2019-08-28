#lang rosette

(require "syntax.rkt")

(define (eval exp refs)
  (match exp
    [(ref* v) (vector-ref refs v)]
    [(not* e) (not (eval e refs))]
    [(and* l r) (and (eval l refs)
                     (eval r refs))]
    [(or* l r) (or (eval l refs)
                   (eval r refs))]
    [(eq* l r) (eq? (eval l refs)
                    (eval r refs))]))

(eq?
 #f
 (eval (and* (or* (not* (ref* 0))
                  (ref* 1))
             (eq* (ref* 2)
                  (ref* 3)))
       (list->vector '(#t #f #t #f))))

(eq?
 #t
 (eval (not* (ref* 0)) (list->vector '(#f))))

(define (multi-assign-helper vars exps refs next-refs)
  (if (pair? vars)
      (multi-assign-helper (cdr vars) (cdr exps) refs
                           (begin (vector-set! next-refs (car vars) (eval (car exps) refs))
                                  next-refs))
      next-refs))

(define (multi-assign vars exps refs)
  (multi-assign-helper vars exps (vector->immutable-vector refs) refs))

(equal?
 (list->vector '(#f #t #f))
 (multi-assign (list 0 1 2)
               (list (ref* 1)
                     (ref* 0)
                     (and* (ref* 1)
                           (ref* 2)))
               (list->vector '(#t #f #t))))

(define (interpret-clause clause refs)
  (match clause
    ['() refs]
    [(clause* guard
              (multi* vars exps)
              tail)
     (if (eval guard refs)
         (multi-assign vars exps refs)
         (interpret-clause tail refs))]))

(interpret-clause (clause* (not* (eq* (ref* 0) (ref* 1)))
                           (multi* (list 0 1)
                                   (list (ref* 1)
                                         (ref* 0)))
                           (clause* (eq* (ref* 0) (ref* 1))
                                    (multi* (list 0)
                                            (list (not* (ref* 0))))
                                    null))
                  (list->vector '(#f #t)))

(interpret-clause (clause* (not* (eq* (ref* 0) (ref* 1)))
                           (multi* (list 0 1)
                                   (list (ref* 1)
                                         (ref* 0)))
                           (clause* (eq* (ref* 0) (ref* 1))
                                    (multi* (list 1)
                                            (list (not* (ref* 1))))
                                    null))
                  (list->vector '(#t #t)))

(provide multi-assign interpret-clause)

                                                                                    
                                                           