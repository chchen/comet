#lang rosette/safe

(require "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         rosette/lib/angelic
         rosette/lib/synthax)

;; type:Symbol -> cxt:List -> List[id:Symbol]
;; where (cons id type) in cxt
(define (type-in-context typ cxt)
  (map car
       (filter (lambda (pair)
                 (eq? typ
                      (cdr pair)))
               cxt)))

(define literals
  (list 'true
        'false
        (?? byte*?)))

;; Inversion over expressions
;; Nat -> Context -> Choose Tree
(define (exp?? depth cxt)
  (let* ([pins (append (type-in-context 'pin-in cxt)
                       (type-in-context 'pin-out cxt))]
         [vars (type-in-context 'byte cxt)]
         [terminals (append (map read* pins)
                            vars
                            literals)])
    (if (positive? depth)
        (apply choose* (append
                        (list (not* (exp?? (sub1 depth) cxt))
                              ((choose* and*
                                        or*
                                        le*
                                        eq*
                                        add*
                                        bwand*
                                        bwor*
                                        shl*
                                        shr*)
                               (exp?? (sub1 depth) cxt)
                               (exp?? (sub1 depth) cxt)))
                        terminals))
        (apply choose* terminals))))

;; Single, "simple" statements
;; variable/pin declaration and
;; variable/pin assignment
;; Nat -> Context -> Choose Tree
(define (simple-stmt?? exp-depth cxt)
  (let* ([inputs (type-in-context 'pin-in cxt)]
         [outputs (type-in-context 'pin-out cxt)]
         [vars (type-in-context 'byte cxt)]
         [i-terms (if (pair? inputs)
                      (list (pin-mode* (apply choose* inputs)
                                       'INPUT))
                      '())]
         [o-terms (if (pair? outputs)
                      (list (pin-mode* (apply choose* outputs)
                                       'OUTPUT)
                            (write* (apply choose* outputs)
                                    (exp?? exp-depth cxt)))
                      '())]
         [v-terms (if (pair? vars)
                      (list (byte* (apply choose* vars))
                            (:=* (apply choose* vars)
                                 (exp?? exp-depth cxt)))
                      '())]
         [choose-terms (append i-terms
                               o-terms
                               v-terms)])
    (apply choose* choose-terms)))

;; Sequence of unconditional statements
;; Nat -> Nat -> Context -> Choose Tree
(define (uncond-stmts?? stmt-depth exp-depth cxt)
  (if (positive? stmt-depth)
      (cons (simple-stmt?? exp-depth cxt)
            (uncond-stmts?? (sub1 stmt-depth)
                            exp-depth
                            cxt))
      '()))

;; Sequence of conditional statements. Think of the
;; conditional expressions on one line, with unconditional
;; statements of length stmt-depth hung on each
;; Nat -> Nat -> Nat -> Context -> Choose Tree
(define (cond-stmts?? cond-depth stmt-depth exp-depth cxt)
  (if (positive? cond-depth)
      (cons (if* (exp?? exp-depth cxt)
                 (uncond-stmts?? stmt-depth
                                 exp-depth
                                 cxt)
                 (cond-stmts?? (sub1 cond-depth)
                               stmt-depth
                               exp-depth
                               cxt))
            '())
      '()))

(provide type-in-context
         exp??
         simple-stmt??
         uncond-stmts??
         cond-stmts??)

;; (define (sym-count u)
;;   (length (symbolics u)))

;; (let ([context (list (cons 'b 'byte)
;;                      (cons 'i 'pin-in)
;;                      (cons 'o 'pin-out))])
;;   (map sym-count
;;        (map (lambda (d) (exp?? d context))
;;             '(0 1 2 3 4 5 6 7 8 9))))

;; (let ([context (list (cons 'b 'byte)
;;                      (cons 'i 'pin-in)
;;                      (cons 'o 'pin-out))])
;;   (map (lambda (e)
;;          (map sym-count
;;               (map (lambda (d)
;;                      (uncond-stmts?? d e context))
;;                    '(1 2 3 4 5 6 7 8 9))))
;;        '(0 1 2 3 4 5)))
