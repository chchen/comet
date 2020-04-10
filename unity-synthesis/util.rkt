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

;; Extract keys from a state mapping
(define (keys state)
  (map car state))

;; Test if states of equal given up to a list of keys
(define (state-eq-modulo-keys? keys state-l state-r)
  (if (null? keys)
      #t
      (let ([id (car keys)]
            [tail (cdr keys)])
        (and (eq? (state-get id state-l)
                  (state-get id state-r))
             (state-eq-modulo-keys? tail state-l state-r)))))

;; Verification wrapper
(define (assert-unsat expr)
  (assert
   (eq?
    (verify (assert expr))
    (unsat))))

(provide equal-length?
         in-list?
         add-mapping
         get-mapping
         state-get
         state-put
         keys
         state-eq-modulo-keys?
         assert-unsat)
