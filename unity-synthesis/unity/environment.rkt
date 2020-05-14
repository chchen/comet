#lang rosette/safe

(require "../util.rkt")

(struct stobj (state))

(struct environment*
  (context
   stobj)
  #:transparent)

(provide stobj
         stobj-state
         environment*
         environment*?
         environment*-context
         environment*-stobj)
