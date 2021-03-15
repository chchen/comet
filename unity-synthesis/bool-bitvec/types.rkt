#lang rosette/safe

(require "../config.rkt")

(define vect?
  (bitvector vect-len))

(define (bool->vect b)
  (bool->bitvector b vect-len))

(provide vect?
         bool->vect)
