#lang rosette

(require "syntax.rkt"
         "../util.rkt")

(define (eval exp env refs)
  (let ([readenv (car env)])
    (match exp
      [(ref* v) (if (in-list? v readenv)
                    (vector-ref refs v)
                    'typerr)]
      [(not* e) (not (eval e env refs))]
      [(and* l r) (and (eval l env refs)
                       (eval r env refs))]
      [(or* l r) (or (eval l env refs)
                     (eval r env refs))]
      [(eq* l r) (eq? (eval l env refs)
                      (eval r env refs))])))

(assert (eq?
         #f
         (eval (and* (or* (not* (ref* 0))
                          (ref* 1))
                     (eq* (ref* 2)
                          (ref* 3)))
               (cons '(0 1 2 3) null)
               (list->vector '(#t #f #t #f)))))

(assert (eq?
         #t
         (eval (not* (ref* 0))
               (cons '(0) null)
               (list->vector '(#f)))))

;; Initialize the environment

(define (interpret-declare-helper decl read write)
  (match decl
    ['() (cons read write)]
    [(declare* ident mode tail) (match mode
                                  ['read (interpret-declare-helper tail
                                                                   (cons ident read)
                                                                   write)]
                                  ['write (interpret-declare-helper tail
                                                                    read
                                                                    (cons ident write))]
                                  ['readwrite (interpret-declare-helper tail
                                                                        (cons ident read)
                                                                        (cons ident write))]
                                  [_ 'typerr])]))

(define (interpret-declare decl)
  (interpret-declare-helper decl '() '()))

(interpret-declare (declare* 0 'readwrite
                             (declare* 1 'write
                                       (declare* 2 'read
                                                 null))))

(define (multi-assign-helper vars exps env refs next-refs)
  (if (cons? vars)
      (let ([var (car vars)]
            [exp (car exps)]
            [writeenv (cdr env)])
        (if (in-list? var writeenv)
            (multi-assign-helper (cdr vars) (cdr exps) env refs
                                 (begin (vector-set! next-refs (car vars) (eval (car exps) env refs))
                                        next-refs))
            'typerr))
      next-refs))

(define (multi-assign vars exps env refs)
  (multi-assign-helper vars exps env (vector->immutable-vector refs) refs))

(assert (equal?
         (list->vector '(#f #t #f))
         (multi-assign (list 0 1 2)
                       (list (ref* 1)
                             (ref* 0)
                             (and* (ref* 1)
                                   (ref* 2)))
                       (cons '(0 1 2)
                             '(0 1 2))
                       (list->vector '(#t #f #t)))))

(define (interpret-clause clause env refs)
  (match clause
    ['() refs]
    [(clause* guard
              (multi* vars exps)
              tail)
     (if (eval guard env refs)
         (multi-assign vars exps env refs)
         (interpret-clause tail env refs))]))

(assert (equal? (list->vector '(#t #f))
                (interpret-clause (clause* (not* (eq* (ref* 0) (ref* 1)))
                           (multi* (list 0 1)
                                   (list (ref* 1)
                                         (ref* 0)))
                           (clause* (eq* (ref* 0) (ref* 1))
                                    (multi* (list 0)
                                            (list (not* (ref* 0))))
                                    null))
                  (cons '(0 1)
                        '(0 1))
                  (list->vector '(#f #t)))))

(assert (equal? (list->vector '(#t #f))
                (interpret-clause (clause* (not* (eq* (ref* 0) (ref* 1)))
                           (multi* (list 0 1)
                                   (list (ref* 1)
                                         (ref* 0)))
                           (clause* (eq* (ref* 0) (ref* 1))
                                    (multi* (list 1)
                                            (list (not* (ref* 1))))
                                    null))
                  (cons '(0 1)
                        '(0 1))
                  (list->vector '(#t #t)))))

(provide multi-assign interpret-clause)

                                                                                    
                                                           