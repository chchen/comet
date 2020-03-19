#lang rosette

(require "../util.rkt"
         "syntax.rkt")

(define (identifier? id)
  (define reserved-symbols
    (list 'false
          'true
          'LOW
          'HIGH
          'INPUT
          'OUTPUT))

  (and (symbol? id)
       (not (in-list? id reserved-symbols))))

(define (type? typ)
  (define types
    (list 'bool
          'pin-in
          'pin-out))

  (in-list? typ types))

(define (context? cxt)
  (cond
    [(null? cxt) #t]
    [(and (pair? cxt)
          (pair? (car cxt)))
     (and (identifier? (caar cxt))
          (type? (cdar cxt))
          (context? (cdr cxt)))]
    [else #f]))

(define (state? st)
  (cond
    [(null? st) #t]
    [(and (pair? st)
          (pair? (car st)))
     (and (identifier? (caar st))
          (or (boolean? (cdar st))
              (level*? (cdar st)))
          (state? (cdr st)))]
    [else #f]))

(struct environment*
  (context
   state)
  #:transparent
  #:guard (lambda (context state type-name)
            (cond
              [(and (context? context)
                    (state? state))
               (values context state)]
              [else (error type-name
                           "bad env: ~a ~a"
                           context
                           state)])))

(provide environment*)

;; Tests

(assert
 (and
  (context? '())
  (context? (list (cons 'x 'bool)
                  (cons 'd0 'pin-in)
                  (cons 'd1 'pin-out)))))

(assert
 (and
  (state? '())
  (state? (list (cons 'x #f)
                (cons 'd0 #t)
                (cons 'd1 #f)))))
