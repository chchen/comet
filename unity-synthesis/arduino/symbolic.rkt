#lang rosette/safe

(require "bitvector.rkt"
         rosette/lib/match)

(define (symbolic-state context)
  (define (symbolic-boolean id)
    (define s (constant id boolean?))
    s)

  (define (symbolic-byte id)
    (define s (constant id word?))
    s)

  (define (helper cxt)
    (match cxt
      ['() '()]
      [(cons (cons id typ) tail)
       (cons (cons id (match typ
                        ['byte (symbolic-byte id)]
                        ['pin-in (symbolic-boolean id)]
                        ['pin-out (symbolic-boolean id)]))
             (helper tail))]))

  (helper context))

(provide symbolic-state)
