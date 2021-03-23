#lang rosette/safe

(require "syntax.rkt"
         rosette/lib/match)

(define (concretize-union union guard)
  (define (helper remaining)
    (if (null? remaining)
        union
        (let* ([condition (caar remaining)]
               [consequent (cdar remaining)])
          (if (unsat? (verify (begin (assume guard)
                                     (assert condition))))
              (concretize-val consequent guard)
              (helper (cdr remaining))))))

  (helper (union-contents union)))

(define (concretize-bool-expr expr guard)
  ;; Try and prove value of the total expression
  (if (unsat? (verify (begin (assume guard)
                             (assert expr))))
      #t
      (if (unsat? (verify (begin (assume guard)
                                 (assert (not expr)))))
          #f
          ;; Try and break down into subexpressions
          (match expr
            [(expression op args ...)
             (apply op (map (lambda (a)
                              (concretize-val a guard))
                            args))]))))

(define (concretize-expr expr guard)
  (if (boolean? expr)
      (concretize-bool-expr expr guard)
      expr))

(define (concretize-val val guard)
  (cond
    [(expression? val) (concretize-expr val guard)]
    [(union? val) (concretize-union val guard)]
    [else val]))

(define (concretize-trace state guard)
  (define (concretize-unity-value val)
    ;; For each complex unity-value type
    (match val
      [(buffer* cursor vals) (buffer* (concretize-val cursor guard)
                                      (map (lambda (e)
                                             (concretize-val e guard))
                                           vals))]
      [(channel* valid value) (channel* (concretize-val valid guard)
                                        (concretize-val value guard))]
      [_ (concretize-val val guard)]))

  (if (null? state)
      '()
      (let* ([id (caar state)]
             [val (cdar state)]
             [tail (cdr state)]
             [concrete-val (concretize-unity-value val)])
        (cons (cons id concrete-val)
              (concretize-trace tail guard)))))

(provide concretize-expr
         concretize-val
         concretize-trace)
