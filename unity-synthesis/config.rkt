#lang rosette/safe

;; (require (only-in racket hash)
;;          rosette/solver/smt/z3
;;          rosette/solver/smt/boolector)

;; (current-solver (z3 ;; #:logic 'QF_BV
;;                     #:options (hash
;;                                ;; ':parallel.threads.max 4
;;                                ':parallel.enable 'true)))

(define vect-len 32)

(current-bitwidth (add1 vect-len))

(provide vect-len)
