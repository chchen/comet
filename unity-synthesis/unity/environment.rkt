#lang rosette

(define (mapping? map)
  (if (null? map)
      #t
      (and (pair? (car map))
           (mapping? (cdr map)))))

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

(provide environment*)
