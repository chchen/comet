#lang rosette/safe

(require "../bool-bitvec/types.rkt")

;; Logical AND
(define (bvland l r)
  (if (and (bitvector->bool l)
           (bitvector->bool r))
      true-vect
      false-vect))

;; Logical OR
(define (bvlor l r)
  (if (or (bitvector->bool l)
          (bitvector->bool r))
      true-vect
      false-vect))

;; Logical NOT
(define (bvlnot l)
  (if (bitvector->bool l)
      false-vect
      true-vect))

;; Equality as a word
(define (bvleq l r)
  (if (bveq l r)
      true-vect
      false-vect))

;; Less-than as a word
(define (bvlult l r)
  (if (bvult l r)
      true-vect
      false-vect))

(provide bvland
         bvlor
         bvlnot
         bvleq
         bvlult)
