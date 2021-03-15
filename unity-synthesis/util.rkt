#lang rosette/safe

(require rosette/lib/match)

(define (eq-symbolic? a b)
  (and (eq? a b)
       (not (term? (eq? a b)))))

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

(define (get-mapping-symbolic key mapping default)
  (if (null? mapping)
      default
      (if (eq-symbolic? key (caar mapping))
          (cdar mapping)
          (get-mapping-symbolic key (cdr mapping) default))))

(define (add-mapping key val mapping)
  (cons (cons key val)
        mapping))

;; Extract a subset of a mapping given a list of keys
(define (subset-mapping keys mapping)
  (filter (lambda (k-v)
            (member (car k-v) keys))
          mapping))

;; Extract a subset of a mapping given a list of keys to exclude
(define (inverse-subset-mapping keys mapping)
  (filter (lambda (k-v)
            (not (member (car k-v) keys)))
          mapping))

;; Extract keys from a mapping
(define (keys mapping)
  (map car mapping))

;; Extract vals from a mapping
(define (vals mapping)
  (map cdr mapping))

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

;; Indentation for pretty-printing
(define (pretty-indent items pre-fix)
  (if (null? items)
      '()
      (cons (if (pair? (car items))
                (pretty-indent (car items) (format "  ~a" pre-fix))
                (format "~a~a" pre-fix (car items)))
            (pretty-indent (cdr items) pre-fix))))

;; Ugh a list prefix function
(define (prefixes lst)
  (define (helper l acc)
    (if (null? l)
        (list acc)
        (cons acc
              (helper (cdr l)
                      (append acc (list (car l)))))))

  (helper lst '()))

(provide eq-symbolic?
         equal-length?
         in-list?
         mapping?
         add-mapping
         get-mapping
         get-mapping-symbolic
         subset-mapping
         inverse-subset-mapping
         keys
         vals
         map-eq-modulo-keys?
         type-in-context
         pretty-indent
         prefixes)
