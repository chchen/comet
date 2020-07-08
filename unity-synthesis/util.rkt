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
  (define (val-eq? k)
    (eq? (get-mapping k map-l)
         (get-mapping k map-r)))

  (andmap val-eq? keys))

;; type:Symbol -> cxt:List -> List[id:Symbol]
;; where (cons id type) in cxt
(define (type-in-context typ cxt)
  (map car
       (filter (lambda (pair)
                 (eq? typ
                      (cdr pair)))
               cxt)))

(provide equal-length?
         in-list?
         mapping?
         add-mapping
         get-mapping
         keys
         map-eq-modulo-keys?
         type-in-context)
