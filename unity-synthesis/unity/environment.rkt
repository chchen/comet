#lang rosette/safe

(require "../util.rkt")

(struct environment*
  (context
   state))

(provide environment*
         environment*?
         environment*-context
         environment*-state)
