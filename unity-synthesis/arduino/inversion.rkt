#lang rosette/safe

(require "../util.rkt"
         "bitvector.rkt"
         "environment.rkt"
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

(define literals
  (list (?? word?)))

(define unops
  (list bvlnot
        bvnot))

(define binops
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
  (let ([terminals (apply choose* (cons (?? word?) vals))])
    (if (positive? depth)
        (let ([l-expr (word-exp?? (sub1 depth) vals)])
          (choose* terminals
                   ((apply choose* unops) l-expr)
                   ((apply choose* binops) l-expr
                                           (word-exp?? (sub1 depth) vals))))
          terminals)))

(define (state?? l-vals expr-depth cxt state)
  (let* ([bool-ids (type-in-context 'pin-out cxt)]
         [word-ids (type-in-context 'byte cxt)]
         [state-values (map (lambda (st)
                              (cond
                                [(word? st) st]
                                [(boolean? st) (bool->word st)]))
                            (map cdr state))])
    (match l-vals
      ['() state]
      [(cons id tail)
       (let* ([id-typ (get-mapping id cxt)])
         (if (eq? id-typ 'pin-in)
             (state?? tail expr-depth cxt state)
             (let* ([hole (word-exp?? expr-depth state-values)]
                    [expr (match id-typ
                            ['byte hole]
                            ['pin-out (bitvector->bool hole)])])
               (cons (cons id expr)
                     (state?? tail expr-depth cxt state)))))])))

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
        (let ([left (exp?? (sub1 depth) cxt extra-exps)]
              [right (exp?? (sub1 depth) cxt extra-exps)])
          (apply choose*
                 (append
                  (list ((choose* not*
                                  bwnot*)
                         left)
                        ((choose* and*
                                  or*
                                  lt*
                                  eq*
                                  add*
                                  bwand*
                                  bwor*
                                  bwxor*
                                  shl*
                                  shr*)
                         left
                         right))
                  terminals)))
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

(provide type-in-context
         state??
         exp??
         context-stmt??
         context-stmts??
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
