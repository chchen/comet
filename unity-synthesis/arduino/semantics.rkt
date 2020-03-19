#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

(define (pin-type? t)
  (match t
    ['pin-in #t]
    ['pin-out #t]
    [_ #f]))

(define (booleans? l r)
  (and (boolean? l)
       (boolean? r)))

(define (same-type? l r)
  (or (booleans? l r)
      (and (level*? l)
           (level*? r))))

(define (eval-and l r)
  (and l r))

(define (eval-or l r)
  (or l r))

(define (eval-eq l r)
  (eq? l r))

(define (eval-not e)
  (not e))

;; Evaluate
(define (evaluate-expr expression context state)
  (define (unexp expr test next)
    (let ([val (eval-helper expr)])
      (if (test val)
          (next val)
          (error 'unexp "type mismatch ~a" expr))))

  (define (binexp left right test next)
    (let ([val-l (eval-helper left)]
          [val-r (eval-helper right)])
      (if (test val-l val-r)
          (next val-l val-r)
          (error 'binexp "type mismatch ~a ~a" left right))))

  (define (eval-helper expr)
    (match expr
      [(and* l r) (binexp l r booleans? eval-and)]
      [(or* l r) (binexp l r booleans? eval-or)]
      [(eq* l r) (binexp l r same-type? eval-eq)]
      [(not* e) (unexp e boolean? eval-not)]
      [(read* p) (if (pin-type? (get-mapping p context))
                     (get-mapping p state)
                     (error 'read "type mismatch ~a" p))]
      ['false #f]
      ['true #t]
      ['LOW (level* #f)]
      ['HIGH (level* #t)]
      [v (if (eq? (get-mapping v context) 'bool)
             (get-mapping v state)
             (error 'deref "type mismatch ~a" v))]))

  (eval-helper expression))

(define (interpret-stmt statement context state)
  (match statement
    ['() (values context state)]
    [(cons (bool* id) tail)
     (interpret-stmt tail
                     (add-mapping id 'bool context)
                     state)]
    [(cons (pin-mode* pin 'INPUT) tail)
     (interpret-stmt tail
                     (add-mapping pin 'pin-in context)
                     state)]
    [(cons (pin-mode* pin 'OUTPUT) tail)
     (interpret-stmt tail
                     (add-mapping pin 'pin-out context)
                     state)]
    [(cons (write* pin expr) tail)
     (let ([typ (get-mapping pin context)]
           [val (evaluate-expr expr context state)])
       (if (and (eq? typ 'pin-out)
                (level*? val))
           (interpret-stmt tail
                           context
                           (add-mapping pin val state))
           (error 'write "type mismatch ~a" statement)))]
    [(cons (:=* var expr) tail)
     (let ([typ (get-mapping var context)]
           [val (evaluate-expr expr context state)])
       (if (and (eq? typ 'bool)
                (boolean? val))
           (interpret-stmt tail
                           context
                           (add-mapping var val state))
           (error 'assign "type mismatch ~a" statement)))]
    [(cons (if* test left right) tail)
     (let ([tval (evaluate-expr test context state)])
       (if (boolean? tval)
           (let*-values ([(branch-to-take) (if tval left right)]
                         [(cxt st) (interpret-stmt branch-to-take context state)])
             (interpret-stmt tail cxt st))
           (error 'if "type mismatch ~a" statement)))]))

(provide evaluate-expr
         interpret-stmt)

;; Tests
(define-symbolic A B boolean?)

(let ([context (list (cons 'a 'bool)
                     (cons 'b 'bool)
                     (cons 'd0 'pin-in)
                     (cons 'd1 'pin-out))]
      [state (list (cons 'a A)
                   (cons 'b B)
                   (cons 'd0 (level* A))
                   (cons 'd1 (level* B)))])
  (assert
   (and
    (equal? (evaluate-expr (not* (and* 'a 'b))
                           context
                           state)
            (evaluate-expr (or* (not* 'a) (not* 'b))
                           context
                           state))
    (boolean? (evaluate-expr (eq* (read* 'd0) (read* 'd1))
                             context
                             state))
    (level*? (evaluate-expr (read* 'd0)
                            context
                            state)))))

(let*-values ([(init-cxt init-st)
               (interpret-stmt (list (bool* 'x)
                                     (bool* 't)
                                     (pin-mode* 'd0 'INPUT)
                                     (pin-mode* 'd1 'OUTPUT)
                                     (:=* 'x 'false)
                                     (write* 'd1 'HIGH))
                               '()
                               '())]
              [(if-cxt if-st)
               (interpret-stmt (list (if* 't
                                          (list (write* 'd1 'HIGH))
                                          (list (write* 'd1 'LOW)))
                                     (:=* 'x 'true))
                               init-cxt
                               (cons (cons 't A)
                                     init-st))])
  (assert (and (equal? (list (cons 'd1 'pin-out)
                             (cons 'd0 'pin-in)
                             (cons 't 'bool)
                             (cons 'x 'bool))
                       init-cxt)
               (equal? (list (cons 'd1 (level* #t))
                             (cons 'x #f))
                       init-st)
               (equal? (get-mapping 'd1 if-st)
                       (level* A))
               (equal? (get-mapping 'x if-st)
                       #t)
               (equal? if-cxt
                       init-cxt))))
