#lang rosette/safe

(require "../bool-bitvec/types.rkt"
         "semantics.rkt"
         "syntax.rkt"
         rosette/lib/match)

(define (symbolic-state context)
  (define (symbolic-boolean)
    (define-symbolic* b boolean?)
    b)

  (define (symbolic-vect)
    (define-symbolic* b vect?)
    b)

  (define (type-mapping->state-mapping typ-map)
    (match typ-map
      [(cons ident typ-decl)
       (cons ident
             (cond
               [(bool-typ? typ-map) (symbolic-boolean)]
               [(vect-typ? typ-map) (symbolic-vect)]))]))

  (map type-mapping->state-mapping context))

(provide symbolic-state)
