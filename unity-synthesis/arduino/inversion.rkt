#lang rosette/safe

(require "../util.rkt"
         "bitvector.rkt"
         "semantics.rkt"
         "symbolic.rkt"
         "syntax.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

;; type:Symbol -> cxt:List -> List[id:Symbol]
;; where (cons id type) in cxt
(define (type-in-context typ cxt)
  (map car
       (filter (lambda (pair)
                 (eq? typ
                      (cdr pair)))
               cxt)))

(define word-unops
  (list bvlnot
        bvnot))

(define word-binops
  (list bvland
        bvlor
        bvlult
        bvleq
        bvadd
        bvand
        bvor
        bvxor
        bvshl
        bvlshr))

(define (word-exp?? depth vals)
  (let* ([terminals (apply choose* vals)])
    (if (zero? depth)
        terminals
        (let* ([l-expr (word-exp?? (sub1 depth) vals)]
               [r-expr (word-exp?? (sub1 depth) vals)]
               [binop ((apply choose* word-binops) l-expr r-expr)]
               [unop ((apply choose* word-unops) l-expr)])
          (choose* terminals binop unop)))))

(define (state?? l-vals r-vals expr-depth cxt state)
  (let ([regularized-vals (map (lambda (v)
                                 (cond
                                   [(boolean? v) (bool->word v)]
                                   [(word? v) v]))
                               r-vals)])

    (define (helper ids)
      (match ids
        ['() state]
        [(cons id tail)
         (let ([id-typ (get-mapping id cxt)])
           (if (eq? id-typ 'pin-in)
               (helper tail)
               (let* ([literals (list (?? word?) true-word false-word)]
                      [vals-plus-literals (append literals regularized-vals)]
                      [hole (word-exp?? expr-depth vals-plus-literals)]
                      [expr (match id-typ
                              ['byte hole]
                              ['pin-out (bitvector->bool hole)])])
                 (cons (cons id expr)
                       (helper tail)))))]))

    (helper l-vals)))


(define binops
  (list and*
        or*
        lt*
        eq*
        add*
        bwand*
        bwor*
        bwxor*
        shl*
        shr*))

(define unops
  (list not*
        bwnot*))

;; Inversion over expressions
;; Nat -> Context -> Choose Tree
(define (exp?? depth cxt extra-exps)
  (let* ([pin-ids (append (type-in-context 'pin-in cxt)
                          (type-in-context 'pin-out cxt))]
         [pin-terms (map read* pin-ids)]
         [var-ids (type-in-context 'byte cxt)]
         [literals (list (?? word?) true-word false-word)]
         [terminals (append pin-terms var-ids literals extra-exps)])

    (define (helper depth)
      (let ([terminal-choice (apply choose* terminals)])
        (if (zero? depth)
            terminal-choice
        (let* ([l-expr (helper (sub1 depth))]
               [r-expr (helper (sub1 depth))]
               [binop ((apply choose* binops) l-expr r-expr)]
               [unop ((apply choose* unops) l-expr)])
          (choose* terminal-choice binop unop)))))

    (helper depth)))

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

;; Sequence of unconditional context-altering statements
;; Nat -> Nat -> Context -> Choose Tree
(define (context-stmts?? stmt-depth cxt)
  (if (positive? stmt-depth)
      (cons (context-stmt?? cxt)
            (context-stmts?? (sub1 stmt-depth)
                             cxt))
      '()))

;; Sequence of conditional statements. Think of the
;; conditional expressions on one line, with unconditional
;; statements of length stmt-depth hung on each
;; Nat -> Guarded-stmts -> Choose Tree
(define (cond-stmts?? cond-depth guarded-stmts)
  (if (positive? cond-depth)
      (let* ([pick (apply choose* guarded-stmts)]
             [guard (guarded-stmt-guard pick)]
             [stmts (guarded-stmt-stmt pick)])
        (cons (if* guard
                   stmts
                   (cond-stmts?? (sub1 cond-depth)
                                 guarded-stmts))
              '()))
      '()))

(define (stmts?? len stmts)
  (if (positive? len)
      (cons (apply choose* stmts)
            (stmts?? (sub1 len)
                     stmts))
      '()))

(provide type-in-context
         state??
         exp??
         context-stmt??
         context-stmts??
         cond-stmts??
         stmts??)

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
