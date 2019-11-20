#lang rosette

(require "syntax.rkt"
         rosette/lib/angelic)

;; Inversion over expressions
(define (exp?? depth env)
  (define (fill-terminals env stub)
    (let ([vars (car env)]
          [pins (append (cadr env)
                        (cddr env))])
      (cond
        [(and (pair? pins)
              (pair? vars))
         (apply choose*
                (read* (apply choose* pins))
                (ref* (apply choose* vars))
                stub)]
        [(and (pair? pins)
              (null? vars))
         (apply choose*
                (read* (apply choose* pins))
                stub)]
        [(and (null? pins)
              (pair? vars))
         (apply choose*
                (ref* (apply choose* vars))
                stub)]
        [else (apply choose* stub)])))
  
  (if (positive? depth)
      (let ([stub (list 'true
                        'false
                        (not* (exp?? (- depth 1) env))
                        ((choose* and*
                                  or*
                                  eq*
                                  neq*)
                         (exp?? (- depth 1) env)
                         (exp?? (- depth 1) env)))])
        (fill-terminals env stub))
      (let ([stub (list 'true
                        'false)])
        (fill-terminals env stub))))

;; Inversion over statements
(define (stmt?? exp-depth stmt-depth env)
  (if (positive? stmt-depth)
      (let ([stub (stmt?? exp-depth (- stmt-depth 1) env)]
            [vars (car env)]
            [pins (cddr env)])
        (cond
          [(and (pair? pins)
                (pair? vars))
           (seq* (choose* (write!* (apply choose* pins)
                                   (exp?? exp-depth env))
                          (set!* (apply choose* vars)
                                 (exp?? exp-depth env)))
                 stub)]
          [(and (pair? pins)
                (null? vars))
           (seq* (choose* (write!* (apply choose* pins)
                                   (exp?? exp-depth env)))
                 stub)]
          [(and (null? pins)
                (pair? vars))
           (seq* (choose* (set!* (apply choose* vars)
                                 (exp?? exp-depth env)))
                 stub)]
          [else '()]))
      '()))

;; Inversion over declarations
(define (decl?? depth env)
  (if (positive? depth)
      (let ([stub (decl?? (- depth 1) env)]
            [vars (car env)]
            [pins (append (cadr env)
                          (cddr env))])
        (cond
          [(and (pair? pins)
                (pair? vars))
           (seq* (choose* (pin-mode* (apply choose* pins)
                                     (choose* 'input 'output))
                          (var* (apply choose* vars)))
                 stub)]
          [(and (pair? pins)
                (null? vars))
           (seq* (pin-mode* (apply choose* pins)
                            (choose* 'input 'output))
                 stub)]
          [(and (null? pins)
                (pair? vars))
           (seq* (var* (apply choose* vars))
                 stub)]
          [else '()]))
      '()))

(provide exp?? stmt?? decl??)
