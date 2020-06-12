#lang rosette/safe

;; Bitvector functions

(define word-size
  8)

(define word?
  (bitvector word-size))

(define true-word
  (bv 1 word-size))

(define false-word
  (bv 0 word-size))

(define (bool->word v)
  (bool->bitvector v word-size))

;; Logical AND
(define (bvland l r)
  (if (and (bitvector->bool l)
           (bitvector->bool r))
      true-word
      false-word))

;; Logical OR
(define (bvlor l r)
  (if (or (bitvector->bool l)
          (bitvector->bool r))
      true-word
      false-word))

;; Logical NOT
(define (bvlnot l)
  (if (bitvector->bool l)
      false-word
      true-word))

;; Equality as a word
(define (bvleq l r)
  (if (bveq l r)
      true-word
      false-word))

;; Less-than as a word
(define (bvlult l r)
  (if (bvult l r)
      true-word
      false-word))

(provide word?
         true-word
         false-word
         bool->word
         bvland
         bvlor
         bvlnot
         bvleq
         bvlult)
