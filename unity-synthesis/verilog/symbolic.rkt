#lang rosette/safe

(require "../bool-bitvec/types.rkt"
         "semantics.rkt"
         rosette/lib/match)

(define (symbolic-state context)
  (define (symbolic-boolean id)
    (define s (constant id boolean?))
    s)

  (define (symbolic-vect id)
    (define s (constant id vect?))
    s)

  (define (type-mapping->state-mapping typ-map)
    (match typ-map
      [(cons ident typ-decl)
       (cons ident
             (cond
               [(bool-typ? typ-map) (symbolic-boolean ident)]
               [(vect-typ? typ-map) (symbolic-vect ident)]))]))

  (map type-mapping->state-mapping context))

(provide symbolic-state)
