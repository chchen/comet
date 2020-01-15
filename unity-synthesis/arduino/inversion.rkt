#lang rosette

(require "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         rosette/lib/angelic)

;; Inversion over expressions
(define (exp?? depth cxt)
  (define (fill-terminals cxt stub)
    (let ([vars (context-vars cxt)]
          [pins (context-readable-pins cxt)])
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
                        (not* (exp?? (- depth 1) cxt))
                        ((choose* and*
                                  or*
                                  eq*
                                  neq*)
                         (exp?? (- depth 1) cxt)
                         (exp?? (- depth 1) cxt)))])
        (fill-terminals cxt stub))
      (let ([stub (list 'true
                        'false)])
        (fill-terminals cxt stub))))

;; Inversion over statements
(define (stmt?? exp-depth stmt-depth cxt)
  (if (positive? stmt-depth)
      (let ([stub (stmt?? exp-depth (- stmt-depth 1) cxt)]
            [vars (context-vars cxt)]
            [pins (context-writable-pins cxt)])
        (cond
          [(and (pair? pins)
                (pair? vars))
           (cons (choose* (write!* (apply choose* pins)
                                   (exp?? exp-depth cxt))
                          (set!* (apply choose* vars)
                                 (exp?? exp-depth cxt)))
                 stub)]
          [(and (pair? pins)
                (null? vars))
           (cons (choose* (write!* (apply choose* pins)
                                   (exp?? exp-depth cxt)))
                 stub)]
          [(and (null? pins)
                (pair? vars))
           (cons (choose* (set!* (apply choose* vars)
                                 (exp?? exp-depth cxt)))
                 stub)]
          [else '()]))
      '()))

(define (guarded-stmt?? guard-count assign-count expression-depth cxt)
  (if (positive? guard-count)
      (cons (if* (exp?? expression-depth cxt)
                 (stmt?? expression-depth assign-count cxt))
            (guarded-stmt?? (- 1 guard-count)
                            assign-count
                            expression-depth
                            cxt))
      '()))

;; Inversion over declarations
(define (decl?? depth cxt)
  (if (positive? depth)
      (let ([stub (decl?? (- depth 1) cxt)]
            [vars (context-vars cxt)]
            [pins (context-readable-pins cxt)])
        (cond
          [(and (pair? pins)
                (pair? vars))
           (cons (choose* (pin-mode* (apply choose* pins)
                                     (choose* 'input 'output))
                          (var* (apply choose* vars)))
                 stub)]
          [(and (pair? pins)
                (null? vars))
           (cons (pin-mode* (apply choose* pins)
                            (choose* 'input 'output))
                 stub)]
          [(and (null? pins)
                (pair? vars))
           (cons (var* (apply choose* vars))
                 stub)]
          [else '()]))
      '()))

(provide exp?? stmt?? guarded-stmt?? decl??)
