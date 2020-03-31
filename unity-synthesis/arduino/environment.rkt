#lang rosette

(require "../util.rkt"
         "syntax.rkt")

(define byte*? (bitvector 8))

(define false-byte (bv 0 8))

(define true-byte (bv 1 8))

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
    (list 'byte
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
          (byte*? (cdar st))
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

(provide environment*
         byte*?
         false-byte
         true-byte)

;; Tests

(assert
 (and
  (context? '())
  (context? (list (cons 'x 'byte)
                  (cons 'd0 'pin-in)
                  (cons 'd1 'pin-out)))))

(assert
 (and
  (state? '())
  (state? (list (cons 'x false-byte)
                (cons 'd0 true-byte)
                (cons 'd1 false-byte)))))
