#lang rosette/safe

(require "types.rkt"
         "../util.rkt"
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match)

(define (typed-alpha-equiv left right)
  (match left
    [(constant l-ident l-typ)
     (match right
       [(constant r-ident r-typ)
        (if (eq? l-typ r-typ)
            (list (cons left right))
            (list 'fail))]
       [_ (list 'fail)])]
    [(&& l-l l-r)
     (match right
       [(&& r-l r-r)
        (let ([normal (append (typed-alpha-equiv l-l r-l)
                              (typed-alpha-equiv l-r r-r))])
          (if (member 'fail normal)
              (append (typed-alpha-equiv l-l r-r)
                      (typed-alpha-equiv l-r r-l))
              normal))]
       [_ (list 'fail)])]
    [(|| l-l l-r)
     (match right
       [(|| r-l r-r)
        (let ([normal (append (typed-alpha-equiv l-l r-l)
                              (typed-alpha-equiv l-r r-r))])
          (if (member 'fail normal)
              (append (typed-alpha-equiv l-l r-r)
                      (typed-alpha-equiv l-r r-l))
              normal))]
       [_ (list 'fail)])]
    [(expression l-op l-args ...)
     (match right
       [(expression r-op r-args ...)
        (if (eq? l-op r-op)
            (apply append
                   (map typed-alpha-equiv
                        l-args
                        r-args))
            (list 'fail))]
       [_ (list 'fail)])]
    [(unity:buffer* l-cur l-val)
     (match right
       [(unity:buffer* r-cur r-val)
        (append (typed-alpha-equiv l-cur r-cur)
                (typed-alpha-equiv l-val r-val))]
       [_ (list 'fail)])]
    [(unity:channel* l-valid l-value)
     (match right
       [(unity:channel* r-valid r-value)
        (append (typed-alpha-equiv l-valid r-valid)
                (typed-alpha-equiv l-value r-value))]
       [_ (list 'fail)])]
    [(list l-elems ...)
     (match right
       [(list r-elems ...)
        (apply append
               (map typed-alpha-equiv
                    l-elems
                    r-elems))]
       [_ (list 'fail)])]
    [_
     (match right
       [(term _ _) (list 'fail)]
       [_ (if (eq? left right)
              '()
              (list 'fail))])]))

(define (apply-subst term subst)
  (define (helper t)
    (match t
      [(constant ident typ)
       (get-mapping-symbolic t subst t)]
      [(expression op args ...)
       (apply op (map helper args))]
      [(unity:buffer* cur val)
       (unity:buffer* (helper cur)
                      (helper val))]
      [(unity:channel* valid value)
       (unity:channel* (helper valid)
                       (helper value))]
      [(list elems ...)
       (map helper
            t)]
      [_ t]))

  (helper term))

(define (try-memo key memos)
  ;; Try and unify key against the key of the memos pair
  ;; If there's a match, apply the computed unifier to the key
  (if (null? memos)
      '()
      (let* ([unity-val (caar memos)]
             [target-val (cdar memos)]
             [unification (typed-alpha-equiv unity-val key)])
        (if (member 'fail unification)
            (try-memo key (cdr memos))
            (apply-subst target-val unification)))))

;; (define-symbolic d2 d4 d5 boolean?)
;; (try-memo (unity:channel* #t d2)
;;           (list (list #t #t)
;;                 (list #f #f)
;;                 (list (unity:channel* #t d4) (! d5) d4)))

(provide try-memo)
