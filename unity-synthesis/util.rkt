#lang rosette

(define (equal-length? a b)
  (and (list? a)
       (list? b)
       (eq? (length a)
            (length b))))

(define (in-list? val l)
  (ormap (lambda (x) (eq? val x)) l))

(provide equal-length?
         in-list?)
