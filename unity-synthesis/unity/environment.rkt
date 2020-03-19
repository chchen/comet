#lang rosette

(require "../util.rkt")

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

(struct environment*
  (context
   state)
  #:transparent
  #:guard (lambda (cxt st type-name)
            (cond
              [(and (mapping? cxt)
                    (mapping? st))
               (values cxt st)]
              [else (error type-name "bad env: ~a ~a" cxt st)])))

(provide mapping?
         cxt-lookup
         environment*
         environment*?
         environment*-context
         environment*-state)
