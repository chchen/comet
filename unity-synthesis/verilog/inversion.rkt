#lang rosette/safe

(require "../util.rkt"
         "../bool-bitvec/types.rkt"
         "syntax.rkt"
         "semantics.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

(define (boolean-terminals cxt)
  (append (list #t #f)
          (map car
               (filter bool-typ? cxt))))

(define (vector-terminals cxt)
  (append (list (?? vect?))
          (map car
               (filter vect-typ? cxt))))

(define bool->bool
  (list not*))

(define vect->vect
  (list bwnot*))

(define bool->bool->bool
  (list and*
        or*
        eq*))

(define vect->vect->bool
  (list bweq*
        lt*))

(define vect->vect->vect
  (list bwand*
        bwor*
        bwxor*
        shl*
        shr*
        add*))

(define (exp?? depth cxt typ bool-snippets)
  (let ([bool-terminals (append bool-snippets
                                (boolean-terminals cxt))]
        [vect-terminals (vector-terminals cxt)])

    (define (boolexp?? depth)
      (let ([terminal-choice (apply choose* bool-terminals)])
        (if (zero? depth)
            terminal-choice
            (let* ([bool-l (boolexp?? (sub1 depth))]
                   [bool-r (boolexp?? (sub1 depth))]
                   [vect-l (vectexp?? (sub1 depth))]
                   [vect-r (vectexp?? (sub1 depth))]
                   [b->b ((apply choose* bool->bool) bool-l)]
                   [b->b->b ((apply choose* bool->bool->bool) bool-l bool-r)]
                   [v->v->b ((apply choose* vect->vect->bool) vect-l vect-r)])
              (choose* terminal-choice
                       b->b
                       b->b->b
                       v->v->b)))))

    (define (vectexp?? depth)
      (let* ([bool-choice (bool->vect* (apply choose* bool-terminals))]
             [vect-choice (apply choose* vect-terminals)]
             [terminal-choice (choose* bool-choice vect-choice)])
        (if (zero? depth)
            terminal-choice
            (let* ([vect-l (vectexp?? (sub1 depth))]
                   [vect-r (vectexp?? (sub1 depth))]
                   [v->v ((apply choose* vect->vect) vect-l)]
                   [v->v->v ((apply choose* vect->vect->vect) vect-l vect-r)])
              (choose* terminal-choice
                       v->v
                       v->v->v)))))

    (cond
      [(eq? typ boolean?) (boolexp?? depth)]
      [(eq? typ vect?) (vectexp?? depth)])))

(provide exp??)

;; Quick Check

;; (define-symbolic A B boolean?)
;; (define-symbolic X Y vect?)

;; (let* ([cxt (list (cons 'a (wire* 1 'a))
;;                   (cons 'b (wire* 1 'b))
;;                   (cons 'x (wire* 8 'x))
;;                   (cons 'y (wire* 8 'y)))]
;;        [st (list (cons 'a A)
;;                  (cons 'b B)
;;                  (cons 'x X)
;;                  (cons 'y Y))]
;;        [bool-sketch (boolexp?? 2 cxt)]
;;        [bool-spec (and (or A B) (bveq X Y))]
;;        [vect-sketch (vectexp?? 2 cxt)]
;;        [vect-spec (bvshl X (bvadd Y Y))]
;;        [bool-model (synthesize
;;                     #:forall st
;;                     #:guarantee (assert (eq? (evaluate-expr bool-sketch st)
;;                                              bool-spec)))]
;;        [vect-model (synthesize
;;                     #:forall st
;;                     #:guarantee (assert (eq? (evaluate-expr vect-sketch st)
;;                                              vect-spec)))])
;;   (list
;;    (evaluate bool-sketch bool-model)
;;    (evaluate vect-sketch vect-model)))
