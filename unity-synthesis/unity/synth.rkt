#lang rosette

(require "syntax.rkt"
         "semantics.rkt")

;; Given a unity program, generate a symbolic state representation.
(define (unity-symbolic-state prog)
  (define (new-sym)
    (define-symbolic* x boolean?)
    x)

  (define (symbolic-state declare)
    (if (pair? declare)
        (match (car declare)
          [(declare* id _) (cons (cons id
                                       (new-sym))
                                 (symbolic-state (cdr declare)))])
        '()))

  (match prog
    [(unity* declare _ _)
     (symbolic-state declare)]))

(provide unity-symbolic-state)
