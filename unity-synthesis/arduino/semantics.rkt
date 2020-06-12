#lang rosette/safe

(require "bitvector.rkt"
         "environment.rkt"
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

;; Evaluate
(define (evaluate-expr expression context state)
  (define (unexp next expr)
    (let ([val (eval-helper expr)])
      (next val)))

  (define (binexp next left right)
    (let ([val-l (eval-helper left)]
          [val-r (eval-helper right)])
      (next val-l val-r)))

  (define (eval-helper expr)
    (match expr
      [(not* e) (unexp bvlnot e)]
      [(and* l r) (binexp bvland l r)]
      [(or* l r) (binexp bvlor l r)]
      [(lt* l r) (binexp bvlult l r)]
      [(eq* l r) (binexp bvleq l r)]
      [(bwnot* e) (unexp bvnot e)]
      [(add* l r) (binexp bvadd l r)]
      [(bwand* l r) (binexp bvand l r)]
      [(bwor* l r) (binexp bvor l r)]
      [(bwxor* l r) (binexp bvxor l r)]
      [(shl* l r) (binexp bvshl l r)]
      [(shr* l r) (binexp bvlshr l r)]
      [(read* p) (unexp bool->word p)]
      ['false false-word]
      ['true true-word]
      ['LOW false-word]
      ['HIGH true-word]
      [v (if (word? v)
             v
             (get-mapping v state))]))

  (eval-helper expression))

(define (interpret-stmt statement context state)
  (match statement
    ['() (environment* context state)]
    [(cons head tail)
     (match head
       [(byte* id)
        (interpret-stmt tail
                        (add-mapping id 'byte context)
                        state)]
       [(pin-mode* pin mode)
        (interpret-stmt tail
                        (add-mapping pin
                                     (case mode
                                       ['INPUT 'pin-in]
                                       ['OUTPUT 'pin-out])
                                     context)
                        state)]
       [(write* pin expr)
        (let ([val (evaluate-expr expr context state)])
          (interpret-stmt tail
                          context
                          (add-mapping pin (bitvector->bool val) state)))]
       [(:=* var expr)
        (let ([val (evaluate-expr expr context state)])
          (interpret-stmt tail
                          context
                          (add-mapping var val state)))]
       [(if* test left right)
        (let ([test-val (evaluate-expr test context state)])
          (let* ([branch-to-take (if (bitvector->bool test-val) left right)]
                 [taken-env (interpret-stmt branch-to-take context state)]
                 [taken-cxt (environment*-context taken-env)]
                 [taken-st (environment*-state taken-env)])
            (interpret-stmt tail taken-cxt taken-st)))])]))

(provide evaluate-expr
         interpret-stmt)

;; Tests
(define-symbolic A B (bitvector 8))

(let ([context (list (cons 'a 'byte)
                     (cons 'b 'byte)
                     (cons 'c 'byte)
                     (cons 'd0 'pin-in)
                     (cons 'd1 'pin-out))]
      [state (list (cons 'a A)
                   (cons 'b B)
                   (cons 'c (bv 1 8))
                   (cons 'd0 (bitvector->bool A))
                   (cons 'd1 (bitvector->bool B)))])
  (assert
   (unsat?
    (verify
     (assert
      (and
       (equal? (evaluate-expr (not* (and* 'a 'b))
                              context
                              state)
               (evaluate-expr (or* (not* 'a) (not* 'b))
                              context
                              state))
       (equal? (evaluate-expr (shl* 'c (bv 1 8))
                              context
                              state)
               (bv 2 8))
       (equal? (evaluate-expr (bv 255 8)
                              context
                              state)
               (bv 255 8))
       (word? (evaluate-expr (eq* (read* 'd0) (read* 'd1))
                             context
                             state))
       (word? (evaluate-expr (read* 'd0)
                             context
                             state))))))))

(let* ([init-env
        (interpret-stmt (list (byte* 'x)
                              (byte* 't)
                              (pin-mode* 'd0 'INPUT)
                              (pin-mode* 'd1 'OUTPUT)
                              (:=* 'x 'false)
                              (write* 'd1 'HIGH))
                        '()
                        '())]
       [init-cxt (environment*-context init-env)]
       [init-st (environment*-state init-env)]
       [if-env
        (interpret-stmt (list (if* 't
                                   (list (write* 'd1 'HIGH))
                                   (list (write* 'd1 'LOW)))
                              (:=* 'x 'true))
                        init-cxt
                        (cons (cons 't A)
                              init-st))]
       [if-cxt (environment*-context if-env)]
       [if-st (environment*-state if-env)])
  (assert
   (unsat?
    (verify
     (assert
      (and (equal? (list (cons 'd1 'pin-out)
                         (cons 'd0 'pin-in)
                         (cons 't 'byte)
                         (cons 'x 'byte))
                   init-cxt)
           (equal? (list (cons 'd1 #t)
                         (cons 'x false-word))
                   init-st)
           (equal? (get-mapping 'd1 if-st)
                   (if (bitvector->bool A)
                       #t
                       #f))
           (equal? (get-mapping 'x if-st)
                   true-word)
           (equal? if-cxt
                   init-cxt)))))))
