#lang rosette

(require "syntax.rkt"
         "../util.rkt")

;; Verifies if the variable v is defined in the read-type environment
(define (can-read? v env)
  (in-list? v (car env)))

;; Verifies if the variable v is defined in the write-type environment
(define (can-write? v env)
  (in-list? v (cdr env)))

;; The latest value of the variable v in the state store.
;; 'referr is returned if v does not exist as a mapping in state
(define (state-get v state)
  (let ([rv (assoc v state)])
    (if rv
        (cdr rv)
        'referr)))

;; Adds a new value mapping for variable v in the state store
(define (state-put v e state)
  (cons (cons v e) state))

;; Evaluate a boolean expression. Takes an expression, a type environment
;; and a state store.
;; 'typerr if variable references violate the type environment
;; 'err if expression syntax is violated
(define (evaluate exp env state)
  (match exp
    [(ref* v) (if (can-read? v env)
                  (state-get v state)
                  'typerr)]
    [(not* e) (not (evaluate e env state))]
    [(and* l r) (and (evaluate l env state)
                     (evaluate r env state))]
    [(or* l r) (or (evaluate l env state)
                   (evaluate r env state))]
    [(eq* l r) (eq? (evaluate l env state)
                    (evaluate r env state))]
    [#t #t]
    [#f #f]
    [_ 'err]))

;; Tests
(assert (eq?
         #f
         (evaluate (and* (or* (not* (ref* 0))
                              (ref* 1))
                         (eq* (ref* 2)
                              (ref* 3)))
                   (cons '(0 1 2 3) null)
                   (list (cons 0 #t)
                         (cons 1 #f)
                         (cons 2 #t)
                         (cons 3 #f))))
        "evaluate-and-eq")

(assert (eq?
         #t
         (evaluate (not* (ref* 0))
                   (cons '(0) null)
                   (list (cons 0 #f))))
        "evaluate-not-ref")

;; --
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

;; Initialize the environment. Takes a list of declaration clauses
;; and returns a type environment.
;; 'typerr if declaration syntax is violated
(define (interpret-declare decl)
  (interpret-declare-helper decl '() '()))

;; Test
(assert (equal?
         (cons (list 2 0)
               (list 1 0))
         (interpret-declare (list (declare* 0 'readwrite)
                                  (declare* 1 'write)
                                  (declare* 2 'read))))
        "interpret-declare")

;; Interpret the multiple assignment inside a multi-assignment
;; clause. The elements of the variable list vars are assigned to
;; the values of the elements of the expression list exps. All
;; expressions are evaluated given the initial state, which is
;; bound to state. Assignments are accumulated to next-state which
;; is the result when vars and exps are exhausted.
(define (interpret-multi-helper vars exps env state next-state)
  (if (and (cons? vars)
           (cons? exps))
      (let ([var (car vars)]
            [exp (car exps)])
        (if (can-write? var env)
            (let ([expval (evaluate exp env state)])
              (interpret-multi-helper (cdr vars)
                                      (cdr exps)
                                      env
                                      state
                                      (state-put var
                                                 expval
                                                 next-state)))
            'typerr))
      next-state))

;; Unpack the variables and expressions from the multi-assignment
;; clause so the interpret-multi-helper can apply the assignments
(define (interpret-multi-clause multi env state next-state)
  (match multi
    [(multi-assignment* variables expressions)
     (interpret-multi-helper variables
                             expressions
                             env
                             state
                             next-state)]))

;; Test
(assert (let ([result
               (let ([refs (list (cons 0 #t)
                                 (cons 1 #f)
                                 (cons 2 #t))])
                 (interpret-multi-clause (multi-assignment*
                                          (list 0 1 2)
                                          (list (ref* 1)
                                                (ref* 0)
                                                (and* (ref* 1)
                                                      (ref* 2))))
                                         (cons '(0 1 2)
                                               '(0 1 2))
                                         refs
                                         refs))])
          (and (not (state-get 0 result))
               (state-get 1 result)
               (not (state-get 2 result))))
        "interpret-multi-clause")

;; Wrapper to interpret the initially multi-assignment
(define (interpret-multi multi env state)
  (interpret-multi-clause multi env state state))

;; Test
(assert (let ([result
               (interpret-multi (multi-assignment* (list 0 1)
                                                   (list #t #f))
                                (cons '()
                                      '(0 1))
                                '())])
          (and (state-get 0 result)
               (not (state-get 1 result))))
        "interpret-multi")

;; Filter the guarded multi-assignments, returning only those whose
;; guards are satisified by the current variable state
(define (filter-guards assignments env state)
  (match assignments
    ['() '()]
    [(cons (assign* guard multi) tail)
     (if (evaluate guard env state)
         (cons multi (filter-guards tail
                                    env
                                    state))
         (filter-guards tail env state))]))

;; Tests
(assert (equal?
         (list 'A 'B 'C)
         (filter-guards (list (assign* (ref* 0) 'A)
                              (assign* (ref* 1) 'B)
                              (assign* (ref* 2) 'C))
                        (cons '(0 1 2)
                              '())
                        (list (cons 0 #t)
                              (cons 1 #t)
                              (cons 2 #t))))
        "filter-guards-t")

(assert (equal?
         '()
         (filter-guards (list (assign* (ref* 0) 'A)
                              (assign* (ref* 1) 'B)
                              (assign* (ref* 2) 'C))
                        (cons '(0 1 2)
                              '())
                        (list (cons 0 #f)
                              (cons 1 #f)
                              (cons 2 #f))))
        "filter-guards-f")

;; --
(define (interpret-multis-helper multis env state next-state)
  (if (pair? multis)
      (interpret-multis-helper (cdr multis)
                               env
                               state
                               (interpret-multi-clause (car multis)
                                                       env
                                                       state
                                                       next-state))
      next-state))

;; Apply all the assignments in a list of multi-assignments. A new
;; state is returned, reflecting the atomic application of all the
;; multi-assignments in the list
(define (interpret-multis multis env state)
  (interpret-multis-helper multis env state state))

;; Test
(assert (let ([result
               (interpret-multis
                (list (multi-assignment* '(0 1)
                                         (list (ref* 1)
                                               (ref* 0)))
                      (multi-assignment* '(2 3)
                                         '(#t #f)))
                (cons '(0 1)
                      '(0 1 2 3))
                (list (cons 0 #f)
                      (cons 1 #t)
                      (cons 2 #f)
                      (cons 3 #t)))])
          (and (state-get 0 result)
               (not (state-get 1 result))
               (state-get 2 result)
               (not (state-get 3 result))))
        "interpret-multis")

;; Wrapper to interpret an assign clause, applying the multi-assignments
;; whose guards are satisified by the current variable state.
(define (interpret-assign assignments env state)
  (let ([multis (filter-guards assignments env state)])
    (interpret-multis multis env state)))

;; Test
(assert (let ([result
               (interpret-assign
                (list (assign* (ref* 0)
                               (multi-assignment* (list 2)
                                                  (list #t)))
                      (assign* (ref* 1)
                               (multi-assignment* (list 3)
                                                  (list #t))))
                (cons '(0 1)
                      '(2 3))
                (list (cons 0 #t)
                      (cons 1 #t)
                      (cons 2 #f)
                      (cons 3 #f)))])
          (and (state-get 0 result)
               (state-get 1 result)
               (state-get 2 result)
               (state-get 3 result)))
        "interpret-assign")

;; Wrapper that produces the variable environment from a UNITY program
(define (interpret-unity-declare prog)
  (match prog
    [(unity* declare initially assign)
     (interpret-declare declare)]))

;; Wrapper that produces the initial variable state from a UNITY program
;; Given some external state.
(define (interpret-unity-initially prog state)
  (match prog
    [(unity* declare initially assign)
     (let ([env (interpret-declare declare)])
       (interpret-multi initially env state))]))

;; Wrapper that applies the assignment clause to a variable state from a
;; UNITY program
(define (interpret-unity-assign prog state)
  (match prog
    [(unity* declare initally assign)
     (let ([env (interpret-declare declare)])
       (interpret-assign assign env state))]))

(provide evaluate
         interpret-declare
         interpret-multi
         interpret-assign
         interpret-unity-declare
         interpret-unity-initially
         interpret-unity-assign
         state-get)

;; Running the interpreter
;; Let's define a program that swaps values between two variables

;; (let ([prog
;;        (unity*
;;         (list (declare* 0 'readwrite)
;;               (declare* 1 'readwrite))
;;         (multi-assignment* (list 0 1)
;;                            (list #t #f))
;;         (list (assign* (not* (eq* (ref* 0) (ref* 1)))
;;                        (multi-assignment* (list 0 1)
;;                                           (list (ref* 1)
;;                                                 (ref* 0))))))])
;;   (let ([initial-state (interpret-unity-initially prog '())])
;;     (interpret-unity-assign prog initial-state)))
