#lang rosette/safe

(require "bitvector.rkt"
         rosette/lib/match)

(define (symbolic-state context)
  (define (symbolic-boolean)
    (define-symbolic* b boolean?)
    b)

  (define (symbolic-byte)
    (define-symbolic* b word?)
    b)

  (define (helper cxt)
    (match cxt
      ['() '()]
      [(cons (cons id typ) tail)
       (cons (cons id (match typ
                        ['byte (symbolic-byte)]
                        ['pin-in (symbolic-boolean)]
                        ['pin-out (symbolic-boolean)]))
             (helper tail))]))

  (helper context))

(provide symbolic-state)
