#lang rosette

(require "environment.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/angelic
         rosette/lib/match
         rosette/lib/synthax)

;; Evaluation function for expressions
(define (evaluate expression environment)
  (match environment
    [(environment*
      (context* cxt-vars
                cxt-read-pins
                cxt-write-pins)
      (state* st-vars
              st-pins))
     (match expression
       [(and* a b) (and (evaluate a environment) (evaluate b environment))]
       [(or* a b) (or (evaluate a environment) (evaluate b environment))]
       [(eq* a b) (eq? (evaluate a environment) (evaluate b environment))]
       [(neq* a b) (not (eq? (evaluate a environment) (evaluate b environment)))]
       [(not* e) (not (evaluate e environment))]
       [(read* p) (if (in-list? p cxt-read-pins)
                      (vector-ref st-pins p)
                      'typerr)]
       [(ref* v) (if (in-list? v cxt-vars)
                     (vector-ref st-vars v)
                     'typerr)]
       ['true #t]
       ['false #f])]))

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
;; (define (interpret stmt cxt state)
;;   (let ([cxt-vars (context-vars cxt)]
;;         [cxt-pins (context-writable-pins cxt)]
;;         [st-vars (state-vars state)]
;;         [st-pins (state-pins state)])
;;     (match stmt
;;       [(cons left right)
;;        (match left
;;          [(write!* p exp) (if (in-list? p cxt-pins)
;;                               (interpret right
;;                                          cxt
;;                                          (state* st-vars
;;                                                  (update! st-pins p (evaluate exp cxt state))))
;;                               'typerr)]
;;          [(set!* v exp) (if (in-list? v cxt-vars)
;;                             (interpret right
;;                                        cxt
;;                                        (state* (update! st-vars v (evaluate exp cxt state))
;;                                                st-pins))
;;                             'typerr)]
;;          [(if* test then-branch) (if (evaluate test cxt state)
;;                                      (interpret right cxt (interpret then-branch cxt state))
;;                                      (interpret right cxt state))])]
;;       ['() state])))

(define (interpret stmt environment)
  (match environment
    [(environment* context state)
     (match context
       [(context* cxt-vars
                  cxt-read-pins
                  cxt-write-pins)
        (match state
          [(state* st-vars
                   st-pins)
           (match stmt
             [(cons left right)
              (match left
                ;; add a new variable to the context
                [(var* id) (interpret right
                                      (environment*
                                       (context* (cons id cxt-vars)
                                                 cxt-read-pins
                                                 cxt-write-pins)
                                       state))]
                ;; add a new pin to the context
                [(pin-mode* id mode) (interpret right
                                                (environment*
                                                 (context* cxt-vars
                                                           (cons id cxt-read-pins)
                                                           (if (eq? mode 'output)
                                                               (cons id cxt-write-pins)
                                                               cxt-write-pins))
                                                 state))]
                ;; write a new pin value to state
                [(write!* p exp) (if (in-list? p cxt-write-pins)
                                     (interpret right
                                                (environment*
                                                 context
                                                 (state* st-vars
                                                         (update! st-pins p (evaluate exp environment)))))
                                     'typerr)]
                ;; write a new variable value to state
                [(set!* v exp) (if (in-list? v cxt-vars)
                                   (interpret right
                                              (environment*
                                               context
                                               (state* (update! st-vars v (evaluate exp environment))
                                                       st-pins)))
                                   'typerr)]
                ;; conditional
                [(if* test then-branch) (if (evaluate test environment)
                                            (interpret right (interpret then-branch environment))
                                            (interpret right environment))])]
                ['() environment])])])]))

(assert
 (equal?
  (env-state
   (interpret (list (write!* 0 (ref* 0)))
              (environment*
               (context* (list 0)
                         '()
                         (list 0))
               (state* (list->vector '(A))
                       (list->vector '(B))))))
  (state* (list->vector '(A))
          (list->vector '(A)))))

(assert
 (equal?
  (env-state
   (interpret (list (if* (eq* (read* 0) (read* 0))
                         (list (set!* 0 (read* 0)))))
              (environment*
               (context* (list 0)
                         (list 0)
                         '())
               (state* (list->vector '(A))
                       (list->vector '(B))))))
  (state* (list->vector '(B))
          (list->vector '(B)))))

(assert
 (equal?
  (env-state
   (interpret (list (if* (neq* (read* 0) (read* 0))
                         (list (set!* 0 (read* 0)))))
              (environment*
               (context* (list 0)
                         (list 0)
                         '())
               (state* (list->vector '(A))
                       (list->vector '(B))))))
  (state* (list->vector '(A))
          (list->vector '(B)))))

(provide evaluate
         interpret
         interpret-decl)
