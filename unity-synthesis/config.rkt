#lang rosette/safe

(require (only-in racket/base error-print-width))

;; (require (only-in racket hash)
;;          rosette/solver/smt/z3
;;          rosette/solver/smt/boolector)

;; (current-solver (z3 ;; #:logic 'QF_BV
;;                     #:options (hash
;;                                ;; ':parallel.threads.max 4
;;                                ':parallel.enable 'true)))

(error-print-width (expt 2 7))

(define vect-len 32)

(current-bitwidth 64)

(provide vect-len)
