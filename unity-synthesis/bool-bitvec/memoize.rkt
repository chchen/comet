#lang rosette/safe

(require "types.rkt"
         "../util.rkt"
         (prefix-in unity: "../unity/syntax.rkt")
         rosette/lib/match)

;; A valid substitution is a function from variables to variables
;; An invalid substitution maps a variable to two different variables
(define (valid-substitution? subst)
  (let* ([unique-subst (remove-duplicates subst concrete-eq?)]
         [keys (map car unique-subst)])
    (= (length keys)
       (length (symbolics keys)))))

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
        (if (or (member 'fail unification)
                (not (valid-substitution? unification)))
            (try-memo key (cdr memos))
            (apply-subst target-val unification)))))

;; [unity-prog->synth-traces] 1889 sec.
;; [unity-val->subtrace] ballot #t 0 sec. ((ballot . (bv #x00000001 32)))
;; [unity-val->subtrace] value #t 0 sec. ((value . (bv #x00000020 32)))
;; [unity-val->subtrace] phase #t 0 sec. ((phase . (bv #x00000001 32)))
;; [unity-val->subtrace] phase #t 0 sec. ((phase . (bv #x000000ff 32)))
;; [unity-val->subtrace] out_a_bal #f 0 sec. #t 0 sec. ((out_a_bal_sent . (bv #x00000000 32)) (out_a_bal_vals . ballot))
;; [unity-val->subtrace] out_b_bal #f 0 sec. #t 1 sec. ((out_b_bal_sent . (bv #x00000000 32)) (out_b_bal_vals . ballot))
;; [unity-val->subtrace] out_c_bal #f 0 sec. #t 0 sec. ((out_c_bal_sent . (bv #x00000000 32)) (out_c_bal_vals . ballot))
;; [unity-val->subtrace] phase #t 0 sec. ((phase . (bv #x00000002 32)))
;; [unity-val->subtrace] out_a #f 1 sec. #f 0 sec. #f 0 sec. #f 814 sec. #t 448 sec. ((d0 . (! d1)) (d2 . (bveq (bv #x00000001 32) (bvand (bv #x00000001 32) (bvlshr out_a_bal_vals out_a_bal_sent)))))
;; [unity-val->subtrace] out_a_bal #f 0 sec. #f 0 sec. #t 0 sec. ((out_a_bal_sent . (bvadd (bv #x00000001 32) out_a_bal_sent)) (out_a_bal_vals . out_a_bal_vals))
;; [unity-val->subtrace] out_b #f 0 sec. #f 1 sec. #f 0 sec. #f 729 sec. #t 403 sec. ((d3 . (! d3)) (d5 . (bveq (bv #x00000000 32) (bvand (bvnot out_b_bal_vals) (bvshl (bv #x00000001 32) out_b_bal_sent)))))
;; [unity-val->subtrace] out_b_bal #t 1 sec. ((out_b_bal_sent . (bvadd (bv #x00000001 32) out_b_bal_sent)) (out_b_bal_vals . out_b_bal_vals))
;; [unity-val->subtrace] out_c #f 0 sec. #f 1 sec. #f 0 sec.

;; (define-symbolic d2 d3 d4 d5 boolean?)
;; (try-memo (unity:channel* #t d2)
;;           (list (list #t #t)
;;                 (list #f #f)
;;                 (list (unity:channel* #t d4) (! d5) d4)))

;; (valid-substitution?
;;  (typed-alpha-equiv (list (unity:channel* #t d2)
;;                           (unity:channel* #t d3))
;;                     (list (unity:channel* #t d4)
;;                           (unity:channel* #t d5))))

;; (define short? (bitvector 4))
;; (define-symbolic out_a_bal_vals out_a_bal_sent out_b_bal_vals out_b_bal_sent short?)
;; (define-symbolic d1 boolean?)

;; (define out-a
;;   (unity:channel*
;;    #t
;;    (|| (&& (! (bveq (bv #b0 1) (extract 0 0 out_a_bal_vals))) (= 0 (bitvector->natural out_a_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 1 1 out_a_bal_vals))) (= 1 (bitvector->natural out_a_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 2 2 out_a_bal_vals))) (= 2 (bitvector->natural out_a_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 3 3 out_a_bal_vals))) (= 3 (bitvector->natural out_a_bal_sent))))))

;; (define out-a-impl
;;   (list (! d1)
;;         (bveq (bv #x00000001 4) (bvand (bv #x00000001 4) (bvlshr out_a_bal_vals out_a_bal_sent)))))

;; (define out-b
;;   (unity:channel*
;;    #t
;;    (|| (&& (! (bveq (bv #b0 1) (extract 0 0 out_b_bal_vals))) (= 0 (bitvector->natural out_b_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 1 1 out_b_bal_vals))) (= 1 (bitvector->natural out_b_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 2 2 out_b_bal_vals))) (= 2 (bitvector->natural out_b_bal_sent)))
;;        (&& (! (bveq (bv #b0 1) (extract 3 3 out_b_bal_vals))) (= 3 (bitvector->natural out_b_bal_sent))))))

;; (try-memo out-b (list (cons out-a out-a-impl)))

(provide try-memo)
