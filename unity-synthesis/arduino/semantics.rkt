#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

;; Evaluation function for expressions
(define (evaluate exp cxt state)
  (let ([cxt-vars (context-vars cxt)]
        [cxt-pins (context-readable-pins cxt)]
        [st-vars (state-vars state)]
        [st-pins (state-pins state)])
    (match exp
      [(and* a b) (and (evaluate a cxt state) (evaluate b cxt state))]
      [(or* a b) (or (evaluate a cxt state) (evaluate b cxt state))]
      [(eq* a b) (eq? (evaluate a cxt state) (evaluate b cxt state))]
      [(neq* a b) (not (eq? (evaluate a cxt state) (evaluate b cxt state)))]
      [(not* e) (not (evaluate e cxt state))]
      [(read* p) (if (in-list? p cxt-pins)
                     (vector-ref st-pins p)
                     'typerr)]
      [(ref* v) (if (in-list? v cxt-vars)
                    (vector-ref st-vars v)
                    'typerr)]
      ['true #t]
      ['false #f])))

(define-symbolic A B boolean?)

;; (let ([in-pins (list->vector (list A))]
;;       [in-refs (list->vector (list B))]
;;       [env (cons '(0)
;;                  (cons '(0) '()))])
;;   (assert (equal? (evaluate (not* (and* (read* 0) (ref* 0)))
;;                         env in-pins in-refs)
;;                   (evaluate (or* (not* (read* 0)) (not* (ref* 0)))
;;                         env in-pins in-refs))))

(define (update! vec key val)
  (vector-set! vec key val)
  vec)

;; Interpretation function for sequences of initialization statements
;; Returns a context
(define (interpret-decl declarations)
  (define (helper decls variables read-pins write-pins)
    (match decls
      [(cons (var* id) tail) (helper tail
                                     (cons id variables)
                                     read-pins
                                     write-pins)]
      [(cons (pin-mode* id mode) tail) (helper tail
                                               variables
                                               (cons id read-pins)
                                               (if (eq? mode 'output)
                                                   (cons id write-pins)
                                                   write-pins))]
      ['() (context* variables read-pins write-pins)]))

  (helper declarations '() '() '()))

;; (assert (equal? (interpret-decl (seq* (var* 'x)
;;                                       (seq* (pin-mode* 0 'input)
;;                                             (seq* (pin-mode* 1 'output)
;;                                                   null))))
;;                 (cons (list 'x)
;;                       (cons (list 1 0)
;;                             (list 1)))))

;; Interpretation function for sequences of statements
(define (interpret stmt cxt state)
  (let ([cxt-vars (context-vars cxt)]
        [cxt-pins (context-writable-pins cxt)]
        [st-vars (state-vars state)]
        [st-pins (state-pins state)])
    (match stmt
      [(cons left right)
       (match left
         [(write!* p exp) (if (in-list? p cxt-pins)
                              (interpret right
                                         cxt
                                         (state* st-vars
                                                 (update! st-pins p (evaluate exp cxt state))))
                              'typerr)]
         [(set!* v exp) (if (in-list? v cxt-vars)
                            (interpret right
                                       cxt
                                       (state* (update! st-vars v (evaluate exp cxt state))
                                               st-pins))
                            'typerr)]
         [(if* test then-branch) (if (evaluate test cxt state)
                                     (interpret right cxt (interpret then-branch cxt state))
                                     (interpret right cxt state))])]
      ['() state])))

(assert
 (equal?
  (interpret (list (write!* 0 (ref* 0)))
             (context* (list 0)
                       '()
                       (list 0))
             (state* (list->vector '(A))
                     (list->vector '(B))))
  (state* (list->vector '(A))
          (list->vector '(A)))))

(assert
 (equal?
  (interpret (list (if* (eq* (read* 0) (read* 0))
                        (list (set!* 0 (read* 0)))))
             (context* (list 0)
                       (list 0)
                       '())
             (state* (list->vector '(A))
                     (list->vector '(B))))
  (state* (list->vector '(B))
          (list->vector '(B)))))

(assert
 (equal?
  (interpret (list (if* (neq* (read* 0) (read* 0))
                        (list (set!* 0 (read* 0)))))
             (context* (list 0)
                       (list 0)
                       '())
             (state* (list->vector '(A))
                     (list->vector '(B))))
  (state* (list->vector '(A))
          (list->vector '(B)))))

(provide evaluate
         interpret
         interpret-decl)
