#lang rosette/safe

(require "../bool-bitvec/types.rkt"
         rosette/lib/match)

(define (symbolic-state context)
  (define (symbolic-boolean id)
    (define s (constant id boolean?))
    s)

  (define (symbolic-word id)
    (define s (constant id vect?))
    s)

  (define (helper cxt)
    (match cxt
      ['() '()]
      [(cons (cons id typ) tail)
       (cons (cons id (match typ
                        ['byte (symbolic-word id)]
                        ['unsigned-int (symbolic-word id)]
                        ['pin-in (symbolic-boolean id)]
                        ['pin-out (symbolic-boolean id)]))
             (helper tail))]))

  (helper context))

(provide symbolic-state)
