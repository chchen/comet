#lang rosette/safe

(define vect-len 8)

(define vect?
  (bitvector vect-len))

(define (bool->vect b)
  (bool->bitvector b vect-len))

(provide vect-len
         vect?
         bool->vect)
