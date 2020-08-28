#lang rosette/safe

(require "../synth.rkt"
         "../util.rkt"
         "bitvector.rkt"
         "semantics.rkt"
         "syntax.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

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
;; Nat -> Context -> Snippets -> Choose Tree
(define (exp?? depth cxt extra-exps)
  (let* ([idents (keys cxt)])
    (exp-modulo-idents?? depth cxt extra-exps idents)))

;; Inversion over expressions
;; Nat -> Context -> Snippets -> Ident-symbols -> Choose Tree
(define (exp-modulo-idents?? depth cxt extra-exps ident-symbols)
  (define (relevant? id)
    (in-list? id ident-symbols))

  (let* ([pin-ids (filter relevant?
                          (append (type-in-context 'pin-in cxt)
                                  (type-in-context 'pin-out cxt)))]
         [pin-terms (map read* pin-ids)]
         [var-ids (filter relevant?
                          (type-in-context 'byte cxt))]
         [terminals (append pin-terms var-ids extra-exps)]
         [literals (list (?? word?) true-word false-word)])

    (define (helper depth)
      (if (zero? depth)
          (let* ([terminal-choice (if (null? terminals)
                                      '()
                                      (list (apply choose* terminals)))]
                 [unop-terminal-choice (if (null? terminal-choice)
                                           '()
                                           (list ((apply choose* unops) terminal-choice)))])
            (apply choose* (append literals terminal-choice unop-terminal-choice)))
          (let* ([l-expr (helper (sub1 depth))]
                 [r-expr (helper (sub1 depth))])
            ((apply choose* binops) l-expr r-expr))))

    (helper depth)))

;; Single, "context-altering" statements
;; variable/pin declaration
;; Nat -> Context -> Choose Tree
(define (context-stmt?? cxt-map)
  (let* ([ident (car cxt-map)]
         [input-term (pin-mode* ident 'INPUT)]
         [output-term (pin-mode* ident 'OUTPUT)]
         [var-term (byte* ident)])
    (choose* input-term output-term var-term)))

;; Produce a sequence that represents an arbitrary ordering, including
;; repetitions, up to an arbitrary length
(define (ordering?? len elements)
  (if (positive? len)
      (cons (apply choose* elements)
            (ordering?? (sub1 len)
                     elements))
      '()))

(provide word-unops
         word-binops
         state??
         exp??
         exp-modulo-idents??
         context-stmt??
         ordering??)

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
