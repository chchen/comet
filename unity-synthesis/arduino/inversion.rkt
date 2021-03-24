#lang rosette/safe

(require "../bool-bitvec/types.rkt"
         "../config.rkt"
         "../symbolic.rkt"
         "../util.rkt"
         "syntax.rkt"
         ;; unsafe! bee careful
         rosette/lib/angelic
         rosette/lib/synthax
         (only-in racket/list permutations))

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
;; Nat -> Context -> Snippets -> Ident-symbols -> Choose Tree
(define (exp-modulo-idents?? depth cxt extra-exps ident-symbols)
  (define (relevant? id)
    (in-list? id ident-symbols))

  (let* ([pin-ids (filter relevant?
                          (append (type-in-context 'pin-in cxt)
                                  (type-in-context 'pin-out cxt)))]
         [pin-terms (map read* pin-ids)]
         [var-ids (filter relevant?
                          (append (type-in-context 'byte cxt)
                                  (type-in-context 'unsigned-int cxt)))]
         [terminals (append pin-terms var-ids extra-exps)]
         [literals (list (?? vect?) (bv 1 vect-len) (bv 0 vect-len))])

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
         [byte-term (byte* ident)]
         [unsigned-int-term (unsigned-int* ident)])
    (choose* input-term output-term byte-term unsigned-int-term)))

;; Produce a sequence that represents an arbitrary ordering, including
;; repetitions, up to an arbitrary length
(define (ordering?? elements)
  (apply choose*
         (map opaque
              (permutations elements))))

(provide exp-modulo-idents??
         context-stmt??
         ordering??)
