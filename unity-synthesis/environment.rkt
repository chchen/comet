#lang rosette/safe

(struct environment*
  (context
   state)
  #:transparent)

(provide environment*
         environment*-context
         environment*-state)
