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
(define (exp?? depth cxt extra-exps)
  (let* ([pins (append (type-in-context 'pin-in cxt)
                       (type-in-context 'pin-out cxt))]
         [vars (type-in-context 'byte cxt)]
         [terminals (append (map read* pins)
                            vars
                            literals
                            extra-exps)])
    (if (positive? depth)
        (apply choose* (append
                        (list (not* (exp?? (sub1 depth) cxt extra-exps))
                              ((choose* and*
                                        or*
                                        lt*
                                        eq*
                                        add*
                                        bwand*
                                        bwor*
                                        shl*
                                        shr*)
                               (exp?? (sub1 depth) cxt extra-exps)
                               (exp?? (sub1 depth) cxt extra-exps)))
                        terminals))
        (apply choose* terminals))))

;; Single, "context-altering" statements
;; variable/pin declaration
;; Nat -> Context -> Choose Tree
(define (context-stmt?? cxt)
  (let* ([inputs (type-in-context 'pin-in cxt)]
         [outputs (type-in-context 'pin-out cxt)]
         [vars (type-in-context 'byte cxt)]
         [i-terms (if (pair? inputs)
                      (list (pin-mode* (apply choose* inputs)
                                       'INPUT))
                      '())]
         [o-terms (if (pair? outputs)
                      (list (pin-mode* (apply choose* outputs)
                                       'OUTPUT))
                      '())]
         [v-terms (if (pair? vars)
                      (list (byte* (apply choose* vars)))
                      '())]
         [choose-terms (append i-terms
                               o-terms
                               v-terms)])
    (apply choose* choose-terms)))

;; Single, "state-changing" statements
;; variable/pin assignment
;; Nat -> Context -> Choose Tree
(define (state-stmt?? exp-depth cxt extra-exps)
  (let* ([outputs (type-in-context 'pin-out cxt)]
         [vars (type-in-context 'byte cxt)]
         [o-terms (if (pair? outputs)
                      (list (write* (apply choose* outputs)
                                    (exp?? exp-depth cxt extra-exps)))
                      '())]
         [v-terms (if (pair? vars)
                      (list (:=* (apply choose* vars)
                                 (exp?? exp-depth cxt extra-exps)))
                      '())]
         [choose-terms (append o-terms
                               v-terms)])
    (apply choose* choose-terms)))

;; Sequence of unconditional context-altering statements
;; Nat -> Nat -> Context -> Choose Tree
(define (context-stmts?? stmt-depth cxt)
  (if (positive? stmt-depth)
      (cons (context-stmt?? cxt)
            (context-stmts?? (sub1 stmt-depth)
                             cxt))
      '()))

;; Sequence of unconditional state-altering statements
;; Nat -> Nat -> Context -> Choose Tree
(define (state-stmts?? stmt-depth exp-depth cxt extra-exps)
  (if (positive? stmt-depth)
      (cons (state-stmt?? exp-depth cxt extra-exps)
            (state-stmts?? (sub1 stmt-depth)
                           exp-depth
                           cxt
                           extra-exps))
      '()))

;; Sequence of conditional statements. Think of the
;; conditional expressions on one line, with unconditional
;; statements of length stmt-depth hung on each
;; Nat -> Expressions -> Statements -> Choose Tree
(define (cond-stmts?? cond-depth exps stmts)
  (if (positive? cond-depth)
      (cons (if* (apply choose* exps)
                 (apply choose* stmts)
                 (cond-stmts?? (sub1 cond-depth)
                               exps
                               stmts))
            '())
      '()))

(provide type-in-context
         exp??
         context-stmt??
         state-stmt??
         context-stmts??
         state-stmts??
         cond-stmts??)

;; (define (sym-count u)
;;   (length (symbolics u)))

;; (let ([context (list (cons 'b 'byte)
;;                      (cons 'i 'pin-in)
;;                      (cons 'o 'pin-out))])
;;   (map sym-count
;;        (map (lambda (d) (exp?? d context '()))
;;             '(0 1 2 3 4 5 6 7 8 9))))

;; (let ([context (list (cons 'b 'byte)
;;                      (cons 'i 'pin-in)
;;                      (cons 'o 'pin-out))])
;;   (map (lambda (e)
;;          (map sym-count
;;               (map (lambda (d)
;;                      (uncond-stmts?? d e context '()))
;;                    '(1 2 3 4 5 6 7 8 9))))
;;        '(0 1 2 3 4 5)))
