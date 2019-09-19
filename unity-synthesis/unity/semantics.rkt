#lang rosette

(require "syntax.rkt"
         "../util.rkt")

(define (can-read? v env)
  (in-list? v (car env)))

(define (can-write? v env)
  (in-list? v (cdr env)))

(define (evaluate exp env refs)
  (match exp
    [(ref* v) (if (can-read? v env)
                  (vector-ref refs v)
                  'typerr)]
    [(not* e) (not (evaluate e env refs))]
    [(and* l r) (and (evaluate l env refs)
                     (evaluate r env refs))]
    [(or* l r) (or (evaluate l env refs)
                   (evaluate r env refs))]
    [(eq* l r) (eq? (evaluate l env refs)
                    (evaluate r env refs))]
    [#t #t]
    [#f #f]))

(assert (eq?
         #f
         (evaluate (and* (or* (not* (ref* 0))
                          (ref* 1))
                     (eq* (ref* 2)
                          (ref* 3)))
               (cons '(0 1 2 3) null)
               (list->vector '(#t #f #t #f))))
        "evaluate-and-eq")

(assert (eq?
         #t
         (evaluate (not* (ref* 0))
               (cons '(0) null)
               (list->vector '(#f))))
        "evaluate-not-ref")

;; Initialize the environment

(define (interpret-declare-helper decl read write)
  (match decl
    ['() (cons read write)]
    [(cons (declare* ident mode) tail)
     (match mode
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

(assert (equal?
         (cons (list 2 0) (list 1 0))
         (interpret-declare (list (declare* 0 'readwrite)
                                  (declare* 1 'write)
                                  (declare* 2 'read))))
        "interpret-declare")

(define (interpret-multi vars exps env refs next-refs)
  (if (cons? vars)
      (let ([var (car vars)]
            [exp (car exps)])
        (if (can-write? var env)
            (interpret-multi (cdr vars) (cdr exps) env refs
                             (begin
                               (vector-set! next-refs
                                            (car vars)
                                            (evaluate (car exps)
                                                      env
                                                      refs))
                               next-refs))
            'typerr))
      next-refs))

(assert (equal?
         (list->vector '(#f #t #f))
         (let ([refs (list->vector '(#t #f #t))])
           (let (
                 [prev (vector->immutable-vector refs)]
                 [next refs])
             (interpret-multi (list 0 1 2)
                              (list (ref* 1)
                                    (ref* 0)
                                    (and* (ref* 1)
                                          (ref* 2)))
                              (cons '(0 1 2)
                                    '(0 1 2))
                              prev
                              next))))
        "interpret-multi")

(define (filter-guards assignments env refs)
  (match assignments
    ['() '()]
    [(cons (assign* guard multi) tail)
     (if (evaluate guard env refs)
         (cons multi (filter-guards tail
                                    env
                                    refs))
         (filter-guards tail env refs))]))

(assert (equal?
         (list 'A 'B 'C)
         (filter-guards (list (assign* (ref* 0) 'A)
                              (assign* (ref* 1) 'B)
                              (assign* (ref* 2) 'C))
               (cons '(0 1 2)
                     '())
               (list->vector '(#t #t #t))))
        "filter-guards-t")

(assert (equal?
         '()
         (filter-guards (list (assign* (ref* 0) 'A)
                              (assign* (ref* 1) 'B)
                              (assign* (ref* 2) 'C))
               (cons '(0 1 2)
                     '())
               (list->vector '(#f #f #f))))
        "filter-guards-f")

(define (interpret-multis-helper multis env prev next)
  (match multis      
    [(cons (multi-assignment* vars exps) tail)
     (interpret-multis-helper tail
                              env
                              prev
                              (interpret-multi vars
                                               exps
                                               env
                                               prev
                                               next))]
    ['() next]))

(define (interpret-initially multi env refs)
  (let ([prev (vector->immutable-vector refs)]
        [next refs])
    (interpret-multi multi env prev next)))

(define (interpret-multis multis env refs)
  (let ([prev (vector->immutable-vector refs)]
        [next refs])
    (interpret-multis-helper multis env prev next)))

(assert (equal?
         (list->vector '(#t #f #t #f))
         (interpret-multis
          (list (multi-assignment* '(0 1)
                                   (list (ref* 1)
                                         (ref* 0)))
                (multi-assignment* '(2 3)
                                   '(#t #f)))
          (cons '(0 1)
                '(0 1 2 3))
          (list->vector '(#f #t #f #t))))
        "interpret-multis")

(define (interpret-assign assignments env refs)
  (let ([multis (filter-guards assignments env refs)])
    (interpret-multis multis env refs)))

(assert (equal?
         (list->vector '(#t #t #t #t))
         (interpret-assign (list (assign* (ref* 0)
                                          (multi-assignment* (list 2)
                                                             (list #t)))
                                 (assign* (ref* 1)
                                          (multi-assignment* (list 3)
                                                             (list #t))))
                           (cons '(0 1)
                                 '(2 3))
                           (list->vector '(#t #t #f #f))))
        "interpret-assign")

(provide interpret-declare
         interpret-initially
         interpret-assign)
