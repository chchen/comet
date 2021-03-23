#lang rosette/safe

;; An opaque struct to prevent the symbolic VM from state merging
(struct opaque
  (val))

(provide opaque
         opaque?
         opaque-val)
