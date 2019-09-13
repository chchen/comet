#lang rosette

(define (in-list? val l)
  (ormap (lambda (x) (eq? val x)) l))

(provide in-list?)
