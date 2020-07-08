#lang rosette/safe

(require "../util.rkt"
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
  (append (list (?? vect?)
                (bv 0 vect-len)
                (bv 1 vect-len))
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
  (list add*
        bwand*
        bwor*
        bwxor*
        shl*
        shr*))

(define (exp?? depth width cxt)
  (let ([bool-terminals (boolean-terminals cxt)]
        [vect-terminals (vector-terminals cxt)])

    (define (subexp?? depth width)
      (let ([bool-terminal-choice (apply choose* bool-terminals)]
            [vect-terminal-choice (apply choose* vect-terminals)])
        (if (zero? depth)
            (match width
              [1 bool-terminal-choice]
              [8 vect-terminal-choice])
            (let* ([l-bool (subexp?? (sub1 depth) 1)]
                   [r-bool (subexp?? (sub1 depth) 1)]
                   [l-vect (subexp?? (sub1 depth) 8)]
                   [r-vect (subexp?? (sub1 depth) 8)]
                   [b->b-exp ((apply choose* bool->bool) l-bool)]
                   [v->v-exp ((apply choose* vect->vect) l-vect)]
                   [b->b->b-exp ((apply choose* bool->bool->bool) l-bool r-bool)]
                   [v->v->b-exp ((apply choose* vect->vect->bool) l-vect r-vect)]
                   [v->v->v-exp ((apply choose* vect->vect->vect) l-vect r-vect)])
              (match width
                [1 (choose* bool-terminal-choice b->b-exp b->b->b-exp v->v->b-exp)]
                [8 (choose* vect-terminal-choice v->v-exp v->v->v-exp)])))))

    (subexp?? depth width)))

(define (boolexp?? depth cxt)
  (exp?? depth 1 cxt))

(define (vectexp?? depth cxt)
  (exp?? depth 8 cxt))

(provide boolexp??
         vectexp??)

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
