#lang rosette

(require "syntax.rkt"
         "../util.rkt")

(define (is-var? id env)
  (let ([varenv (car env)])
    (in-list? id varenv)))

(define (can-read? id env)
  (let ([readenv (cadr env)])
    (in-list? id readenv)))

(define (can-write? id env)
  (let ([writeenv (cddr env)])
    (in-list? id writeenv)))

(define (var-id? id)
  (symbol? id))

(define (pin-id? id)
  (and (integer? id)
       (>= id 0)))

(define (valid-expression? expression env)
  (match expression
    ['true #t]
    ['false #t]
    [(read* p) (and (pin-id? p)
                    (can-read? p env))]
    [(ref* v) (and (var-id? v)
                   (is-var? v env))]
    [(or (and* a b)
         (or* a b)
         (eq* a b)
         (neq* a b)) (and (valid-expression? a env)
                          (valid-expression? b env))]
    [(not* a) (valid-expression? a env)]
    [_ #f]))

(define (valid-statement? statement env)
  (match statement
    ['() #t]
    [(seq* (var* v)
           tail) (and (var-id? v)
                      (valid-statement? tail env))]
    [(seq* (pin-mode* p m)
           tail) (and (pin-id? p)
                      (or (eq? m 'input)
                          (eq? m 'output))
                      (valid-statement? tail env))]
    [(seq* (write!* p e)
           tail) (and (pin-id? p)
                      (can-write? p env)
                      (valid-expression? e env)
                      (valid-statement? tail env))]
    [(seq* (set!* v e)
           tail) (and (var-id? v)
                      (is-var? v env)
                      (valid-expression? e env)
                      (valid-statement? tail env))]
    [(seq* (if* e b)
           tail) (and (valid-expression? e env)
                      (valid-statement? b env)
                      (valid-statement? tail env))]
    [_ #f]))

(define (valid-program? program env)
  (match program
    [(arduino* (setup* s-stmt)
               (loop* l-stmt)) (and (valid-statement? s-stmt env)
                                    (valid-statement? l-stmt env))]))

(provide valid-program?
         valid-statement?
         valid-expression?)

(assert (valid-program?
         (arduino* (setup* null)
                   (loop* null))
         null))

(assert (valid-expression?
         (eq* (read* 0)
              (ref* 'x))
         (cons (list 'x)
               (cons (list 0)
                     null))))

(assert (valid-program?
         (arduino* (setup* (seq* (var* 'x)
                                 (seq* (pin-mode* 0 'input)
                                       (seq* (pin-mode* 1 'output)
                                             (seq* (set!* 'x 'true)
                                                   (seq* (write!* 1 'false)
                                                         null))))))
                   (loop* (seq* (if* (eq* (read* 0)
                                          (ref* 'x))
                                     (seq* (set!* 'x (not* (ref* 'x)))
                                           (seq* (write!* 1 (not* (read* 1)))
                                                 null)))
                                null)))
         (cons (list 'x)
               (cons (list 0 1)
                     (list 1)))))

(assert (valid-expression?
         (and*
          (eq* (eq* 'false (read* 3)) (or* 'false (read* 4)))
          (and* (eq* (not* (read* 1)) (read* 0)) (eq* (read* 7) (read* 6))))
         (cons '()
               (cons (list 8 7 6 5 4 3 2 1 0)
                     (list 8 6 4 1)))))
