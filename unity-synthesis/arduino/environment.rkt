#lang rosette/safe

(require "../util.rkt"
         "syntax.rkt")

(define byte*? (bitvector 8))

(define false-byte (bv 0 8))

(define true-byte (bv 1 8))

(struct environment*
  (context
   state)
  #:transparent)

(provide byte*?
         false-byte
         true-byte
         environment*
         environment*-context
         environment*-state)
