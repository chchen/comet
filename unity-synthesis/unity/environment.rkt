#lang rosette/safe

(require "../util.rkt")

(struct environment*
  (context
   state)
  #:transparent)

(provide environment*
         environment*?
         environment*-context
         environment*-state)
