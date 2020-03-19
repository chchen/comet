#lang rosette

(define (equal-length? a b)
  (and (list? a)
       (list? b)
       (eq? (length a)
            (length b))))

(define (in-list? val l)
  (ormap (lambda (x) (eq? val x)) l))

;; We use a unified state representation for our models, a associative list from
;; symbol to value.

(define (get-mapping key mapping)
  (match (assoc key mapping)
    [(cons _ val) val]
    [_ null]))

(define (add-mapping key val mapping)
  (cons (cons key val)
        mapping))

(define (state-get id state)
  (get-mapping id state))

(define (state-put id val state)
  (add-mapping id val state))

(provide equal-length?
         in-list?
         add-mapping
         get-mapping
         state-get
         state-put)
