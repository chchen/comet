#lang rosette

(require "syntax.rkt"
         rosette/lib/synthax
         rosette/lib/angelic)

;; Inversion over expressions
(define-synthax (exp?? depth)
  #:base (choose #t
                 #f
                 (read* (choose 0 1 2 3 4 5 6 7 8 9 10 11 12 13))
                 (ref* (??)))
  #:else (choose #t
                 #f
                 (read* (choose 0 1 2 3 4 5 6 7 8 9 10 11 12 13))
                 (ref* (??))
                 (not* (exp?? (- depth 1)))
                 ((choose and* or* eq* neq*)
                  (exp?? (- depth 1))
                  (exp?? (- depth 1)))))

;; Inversion over sequences of statements (in this case, writes)
(define-synthax (stmt?? edepth depth)
  #:base null
  #:else (choose null
                 (seq* (choose (write!* (choose 0 1 2 3 4 5 6 7 8 9 10 11 12 13)
                                       (exp?? edepth))
                               (set!* (??)
                                      (exp?? edepth)))
                       (stmt?? edepth (- depth 1)))))

;; Inversion over guarded statements (one guard with sequences of statements in the
;; consequence blocks
(define-synthax (guardstmt?? expdepth blockdepth depth)
  #:base null
  #:else (choose null
                 (seq* (if* (exp?? expdepth)
                            (stmt?? expdepth blockdepth))
                       (guardstmt?? expdepth blockdepth (- depth 1)))))

(provide exp?? stmt?? guardstmt??)