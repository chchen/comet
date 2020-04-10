#lang rosette/safe

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

(define (true-byte? b)
  (not (bveq b false-byte)))

(define (false-byte? b)
  (bveq b false-byte))

;; Coerce bytes into boolean 0x0 or 0x1
;; Non-zero bytes -> 0x1
;; Zero bytes -> 0x0
(define (bool-byte b)
  (if (false-byte? b)
      false-byte
      true-byte))

(define (eval-not e)
  (if (false-byte? e)
      true-byte
      false-byte))

(define (eval-and l r)
  (if (false-byte? l)
      l
      r))

(define (eval-or l r)
  (if (false-byte? l)
      r
      l))

(define eval-le bvult)

(define (eval-eq l r)
  (if (bveq l r)
      true-byte
      false-byte))

(define eval-add bvadd)

(define eval-bwand bvand)

(define eval-bwor bvor)

(define eval-shl bvshl)

(define eval-shr bvlshr)

;; Evaluate
(define (evaluate-expr expression context state)
  (define (unexp expr test next)
    (let ([val (eval-helper expr)])
      (if (test val)
          (next val)
          'bad-unexp)))

  (define (binexp left right test next)
    (let ([val-l (eval-helper left)]
          [val-r (eval-helper right)])
      (if (and (test val-l)
               (test val-r))
          (next val-l val-r)
          'bad-binexp)))

  (define (eval-helper expr)
    (match expr
      [(not* e) (unexp e byte*? eval-not)]
      [(and* l r) (binexp l r byte*? eval-and)]
      [(or* l r) (binexp l r byte*? eval-or)]
      [(le* l r) (binexp l r byte*? eval-le)]
      [(eq* l r) (binexp l r byte*? eval-eq)]
      [(add* l r) (binexp l r byte*? eval-add)]
      [(bwand* l r) (binexp l r byte*? eval-bwand)]
      [(bwor* l r) (binexp l r byte*? eval-bwor)]
      [(shl* b d) (binexp b d byte*? eval-shl)]
      [(shr* b d) (binexp b d byte*? eval-shr)]
      [(read* p) (if (pin-type? (get-mapping p context))
                     (bool-byte (get-mapping p state))
                     'bad-read)]
      ['false false-byte]
      ['true true-byte]
      ['LOW false-byte]
      ['HIGH true-byte]
      [v (cond
           [(eq? (get-mapping v context) 'byte) (get-mapping v state)]
           [(byte*? v) v]
           [else 'bad-literal])]))

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
                                       ['OUTPUT 'pin-out]
                                       [else 'bad-pinmode])
                                     context)
                        state)]
       [(write* pin expr)
        (let ([typ (get-mapping pin context)]
              [val (evaluate-expr expr context state)])
          (if (and (eq? typ 'pin-out)
                   (byte*? val))
              (interpret-stmt tail
                              context
                              (add-mapping pin (bool-byte val) state))
              'bad-write))]
       [(:=* var expr)
        (let ([typ (get-mapping var context)]
              [val (evaluate-expr expr context state)])
          (if (and (eq? typ 'byte)
                   (byte*? val))
              (interpret-stmt tail
                              context
                              (add-mapping var val state))
              'bad-assign))]
       [(if* test left right)
        (let ([tval (evaluate-expr test context state)])
          (if (byte*? tval)
              (let* ([branch-to-take (if (true-byte? tval) left right)]
                     [taken-env (interpret-stmt branch-to-take context state)]
                     [taken-cxt (environment*-context taken-env)]
                     [taken-st (environment*-state taken-env)])
                (interpret-stmt tail taken-cxt taken-st))
              'bad-if))])]))

(provide true-byte?
         false-byte?
         evaluate-expr
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
                   (cons 'd0 (bool-byte A))
                   (cons 'd1 (bool-byte B)))])
  (assert-unsat
   (and
    (equal? (evaluate-expr (not* (and* 'a 'b))
                           context
                           state)
            (evaluate-expr (or* (not* 'a) (not* 'b))
                           context
                           state))
    (equal? (evaluate-expr (shr* 'c)
                           context
                           state)
            (bv 2 8))
    (equal? (evaluate-expr (bv 255 8)
                           context
                           state)
            (bv 255 8))
    (byte*? (evaluate-expr (eq* (read* 'd0) (read* 'd1))
                           context
                           state))
    (byte*? (evaluate-expr (read* 'd0)
                           context
                           state)))))

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
  (assert-unsat
   (and (equal? (list (cons 'd1 'pin-out)
                      (cons 'd0 'pin-in)
                      (cons 't 'byte)
                      (cons 'x 'byte))
                init-cxt)
        (equal? (list (cons 'd1 true-byte)
                      (cons 'x false-byte))
                init-st)
        (equal? (get-mapping 'd1 if-st)
                (if (true-byte? A)
                    true-byte
                    false-byte))
        (equal? (get-mapping 'x if-st)
                true-byte)
        (equal? if-cxt
                init-cxt))))
