#lang rosette/safe

(require "../util.rkt"
         "syntax.rkt")

(struct environment*
  (context
   state)
  #:transparent)

(provide environment*
         environment*-context
         environment*-state)
