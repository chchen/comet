#lang rosette/safe

(require rosette/lib/match)

(define (equal-length? a b)
  (and (list? a)
       (list? b)
       (eq? (length a)
            (length b))))

(define (in-list? val l)
  (ormap (lambda (x) (eq? val x)) l))

;; We use a unified state representation for our models, a associative list from
;; symbol to value.

(define (mapping? map)
  (if (null? map)
      #t
      (and (pair? map)
           (pair? (car map))
           (mapping? (cdr map)))))

(define (get-mapping key mapping)
  (match (assoc key mapping)
    [(cons _ val) val]
    [_ null]))

(define (add-mapping key val mapping)
  (cons (cons key val)
        mapping))

;; Extract keys from a state mapping
(define (keys state)
  (map car state))

;; Test if maps are equal given up to a list of keys
(define (map-eq-modulo-keys? keys map-l map-r)
  (if (null? keys)
      #t
      (let ([id (car keys)]
            [tail (cdr keys)])
        (and (eq? (get-mapping id map-l)
                  (get-mapping id map-r))
             (map-eq-modulo-keys? tail map-l map-r)))))

;; Test if maps are equal given up to a list of keys
;; And if the key is defined in the reference mapping
(define (map-eq-modulo-keys-test-reference? keys test reference)
  (if (null? keys)
      #t
      (let* ([id (car keys)]
             [tail (cdr keys)]
             [reference-value (get-mapping id reference)]
             [tail-eq? (map-eq-modulo-keys-test-reference? tail test reference)])
        (if (null? reference-value)
            tail-eq?
            (and (eq? (get-mapping id test)
                      reference-value)
                 tail-eq?)))))

(provide equal-length?
         in-list?
         mapping?
         add-mapping
         get-mapping
         keys
         map-eq-modulo-keys-test-reference?)
