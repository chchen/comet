#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

(define natural? exact-nonnegative-integer?)

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
          (error 'unexp "type mismatch ~a state: ~a" expr state))))

  (define (binexp left right test next)
    (let ([val-l (eval-helper left)]
          [val-r (eval-helper right)])
      (if (and (test val-l)
               (test val-r))
          (next val-l val-r)
          (error 'binexp "type mismatch ~a ~a state: ~a" left right state))))

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
                     (error 'read "type mismatch ~a" p))]
      ['false false-byte]
      ['true true-byte]
      ['LOW false-byte]
      ['HIGH true-byte]
      [v (cond
           [(eq? (get-mapping v context) 'byte) (get-mapping v state)]
           [(natural? v) (bv v 8)]
           [else (error 'deref "type mismatch ~a" v)])]))

  (eval-helper expression))

(define (interpret-stmt statement context state)
  (match statement
    ['() (values context state)]
    [(cons (byte* id) tail)
     (interpret-stmt tail
                     (add-mapping id 'byte context)
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
                (byte*? val))
           (interpret-stmt tail
                           context
                           (add-mapping pin (bool-byte val) state))
           (error 'write "type mismatch ~a" statement)))]
    [(cons (:=* var expr) tail)
     (let ([typ (get-mapping var context)]
           [val (evaluate-expr expr context state)])
       (if (and (eq? typ 'byte)
                (byte*? val))
           (interpret-stmt tail
                           context
                           (add-mapping var val state))
           (error 'assign "type mismatch ~a" statement)))]
    [(cons (if* test left right) tail)
     (let ([tval (evaluate-expr test context state)])
       (if (byte*? tval)
           (let*-values ([(branch-to-take) (if (true-byte? tval) left right)]
                         [(cxt st) (interpret-stmt branch-to-take context state)])
             (interpret-stmt tail cxt st))
           (error 'if "type mismatch ~a" statement)))]))

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
                   (cons 'c (bv 42 8))
                   (cons 'd0 (bool-byte A))
                   (cons 'd1 (bool-byte B)))])
  (assert
   (and
    (equal? (evaluate-expr (not* (and* 'a 'b))
                           context
                           state)
            (evaluate-expr (or* (not* 'a) (not* 'b))
                           context
                           state))
    (equal? (evaluate-expr 'c
                           context
                           state)
            (evaluate-expr 42
                           context
                           state))
    (byte*? (evaluate-expr (eq* (read* 'd0) (read* 'd1))
                             context
                             state))
    (byte*? (evaluate-expr (read* 'd0)
                            context
                            state)))))

(let*-values ([(init-cxt init-st)
               (interpret-stmt (list (byte* 'x)
                                     (byte* 't)
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
                             (cons 't 'byte)
                             (cons 'x 'byte))
                       init-cxt)
               (equal? (list (cons 'd1 true-byte)
                             (cons 'x false-byte))
                       init-st)
               (equal? (get-mapping 'd1 if-st)
                       A)
               (equal? (get-mapping 'x if-st)
                       true-byte)
               (equal? if-cxt
                       init-cxt))))
