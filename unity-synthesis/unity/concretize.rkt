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
              (begin
                (assume condition)
                (concretize-val consequent guard))
              (helper (cdr remaining))))))

  (helper (union-contents union)))

(define (concretize-bool-expr expr guard)
  ;; Try and prove value of the total expression
  (if (unsat? (verify (begin (assume guard)
                             (assert expr))))
      (begin
        (assume expr)
        #t)
      (if (unsat? (verify (begin (assume guard)
                                 (assert (not expr)))))
          (begin
            (assume (not expr))
            #f)
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
    ;; symbolic expressions/unions
    [(expression? val) (concretize-expr val guard)]
    [(union? val) (concretize-union val guard)]
    ;; complex unity values
    [(buffer*? val) (buffer* (concretize-val (buffer*-cursor val)
                                             guard)
                             (map (lambda (e)
                                    (concretize-val e guard))
                                  (buffer*-vals val)))]
    [(channel*? val) (channel* (concretize-val (channel*-valid val)
                                           guard)
                           (concretize-val (channel*-value val)
                                           guard))]
    [else val]))

(define (concretize-trace state guard)
  (if (null? state)
      '()
      (let* ([id (caar state)]
             [val (cdar state)]
             [tail (cdr state)]
             [concrete-val (concretize-val val)])
        (cons (cons id concrete-val)
              (concretize-trace tail guard)))))

(provide concretize-expr
         concretize-val
         concretize-trace)
