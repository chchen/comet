#lang rosette

(require "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/match)

(define (reserved-symbol? symbol)
  (match symbol
    ['empty #t]
    [_ #f]))

(define (valid-identifier? id)
  (and (symbol? id)
       (not (reserved-symbol? id))))

(define (valid-type? type)
  (match type
    ['boolean #t]
    ['channel #t]
    [_ #f]))

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
    [(cons (cons x 'channel) tail)
     (cons (cons x (channel* (symbolic-boolean)
                             (symbolic-boolean)))
           (symbolic-state tail))]))

;; Validate a declaration clause. Each pair if (id, type) must be a valid id
;; (not a reserved symbol, valid type) and each id should be declared only once
(define (declare-ok? prog)     
  (define (check decl processed)
    (match decl
      ['() #t]
      [(cons (cons id type) tail)
       (and (valid-identifier? id)
            (valid-type? type)
            (not (in-list? id processed))
            (check tail (cons id processed)))]))

  (match prog
    [(unity* (declare* declarations) _ _)
     (and (list? declarations)
          (check declarations '()))]))

(define (initially-ok? prog)
  (let ([env (interpret-declare prog)])
  (environment*? (interpret-initially prog env))))

(define (assign-ok? prog)
  (let* ([initial-env (interpret-declare prog)]
         [cxt (environment*-context initial-env)]
         [state (symbolic-state cxt)]
         [env (environment* cxt state)]
         [model
          (verify
           #:guarantee
           (assert
            (environment*? (interpret-assign prog env))))])
    (if (eq? (unsat) model)
        #t
        (error 'assign-ok "counterexample: ~a" (evaluate state model)))))

(define (program-ok? prog)
  (and (declare-ok? prog)
       (initially-ok? prog)
       (assign-ok? prog)))

(provide program-ok?)

;; Tests

(assert
 (let* ([prog
         (unity*
          (declare* (list (cons 'r 'boolean)
                          (cons 'c 'channel)))
          (initially* (:=* (list 'r
                                 'c)
                           (list #f
                                 'empty)))
          (assign* (list (:=* (list 'r
                                    'c)
                              (case* (list (cons (list (not* 'r)
                                                       (message* #t))
                                                 (empty?* 'c)))))
                         (:=* (list 'c)
                              (case* (list (cons (list 'empty)
                                                 (full?* 'c))))))))])
 (program-ok? prog)))
