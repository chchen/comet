#lang rosette

(require "arduino/syntax.rkt"
         "arduino/semantics.rkt"
         "arduino/inversion.rkt"
         "fifo-spec.rkt"
         rosette/lib/synthax)

(define-symbolic lR lA rR rA boolean?)

(define sl (list lR lA rR rA))

;; First we see if we can find an assignment of concrete terminal
(define terminalsketch
  (seq* (if* (and* (neq* (read* (??))
                         (read* (??)))
                   (eq* (read* (??))
                        (read* (??))))
             (seq* (write!* (??) (read* (??)))
                   (seq* (write!* (??) (not* (read* (??))))
                         null)))
        null))

(define TS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (car (interpret terminalsketch (list->vector sl) '()))
                               (fifospec (list->vector sl))))))

(evaluate terminalsketch TS)

;; Can we synthesize the guard expression?
(define guardsketch
  (exp?? 2))

(define GS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (eval guardsketch (list->vector sl) '())
                               (guardspec (list->vector sl))))))

(evaluate guardsketch GS)

;; Factoring out the assignment, one at a time (targets are still fixed)
(define wholesketch
  (seq* (if* (evaluate guardsketch GS)
             (seq* (write!* 1 (exp?? 0))
                   (seq* (write!* 2 (exp?? 1))
                         null)))
        null))

(define WS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (car (interpret wholesketch (list->vector sl) '()))
                               (fifospec (list->vector sl))))))

(evaluate wholesketch WS)

;; Can we synthesize a single assignment
(define assignsketch
  (stmt?? 1 1))

(define AS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (car (interpret assignsketch (list->vector sl) '()))
                               (assignspec (list->vector sl))))))

(evaluate assignsketch AS)

;; Can we synthesize entire assignment sequences
(define seqsketch
  (stmt?? 1 2))

(define QS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (car (interpret seqsketch (list->vector sl) '()))
                               (actionspec (list->vector sl))))))

(evaluate seqsketch QS)

;; What about the whole enchilada
(define progsketch
  (guardstmt?? 2 2 1))

(define PS
  (synthesize
   #:forall sl
   #:guarantee (assert (equal? (car (interpret progsketch (list->vector sl) '()))
                               (fifospec (list->vector sl))))))

(evaluate progsketch PS)