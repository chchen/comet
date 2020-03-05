#lang rosette

(define (mapping? map)
  (if (null? map)
      #t
      (and (pair? map)
           (pair? (car map))
           (mapping? (cdr map)))))

(define (cxt-lookup id cxt)
  (match (assoc id cxt)
    [(cons _ type) type]
    [_ (error 'cxt-lookup "no type mapping for ~a in context ~a" id cxt)]))

;; The latest value of the variable id in the state store.
(define (state-get id state)
  (match (assoc id state)
    [(cons _ val) val]
    [_ null]))

;; Adds a new value mapping for variable id in the state store
(define (state-put id val state)
  (cons (cons id val) state))

(struct environment*
  (context
   state)
  #:transparent
  #:guard (lambda (cxt st type-name)
            (cond
              [(and (mapping? cxt)
                    (mapping? st))
               (values cxt st)]
              [else (error type-name "bad vals: ~a ~a" cxt st)])))

(provide mapping?
         cxt-lookup
         state-get
         state-put
         environment*
         environment*?)
