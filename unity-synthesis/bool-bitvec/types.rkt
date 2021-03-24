#lang rosette/safe

(require "../config.rkt")

(define vect?
  (bitvector vect-len))

(define (bool->vect b)
  (bool->bitvector b vect-len))

(define false-vect
  (bv 0 vect-len))

(define true-vect
  (bv 1 vect-len))

(provide vect?
         bool->vect
         false-vect
         true-vect)
