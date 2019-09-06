#lang rosette

(require (prefix-in arduino: "arduino/syntax.rkt")
         (prefix-in arduino-sem: "arduino/semantics.rkt")
         "arduino/inversion.rkt"
         (prefix-in unity: "unity/syntax.rkt")
         (prefix-in unity-sem: "unity/semantics.rkt")
         rosette/lib/synthax)

;; Synthesize an equivalent to a multi-assignment swap

(define (multi-assign-swap input-state)
  (unity-sem:multi-assign (list 0 1)
                          (list (unity:ref* 1)
                                (unity:ref* 0))
                          input-state))

(multi-assign-swap (list->vector '(#t #f)))

(define-symbolic left right aux boolean?)

(define pins (list left right))
(define refs (list aux))

;; First we see if we can find an assignment of concrete terminal
(define terminal-sketch
  (arduino:seq* (arduino:set!* (??) (arduino:read* (??)))
                (arduino:seq* (arduino:write!* (??) (arduino:read* (??)))
                              (arduino:seq* (arduino:write!* (??) (arduino:ref* (??)))
                                            null))))

(define TS
  (synthesize
   #:forall pins
   #:guarantee (assert (equal? (car (arduino-sem:interpret terminal-sketch (list->vector pins) (list->vector refs)))
                               (multi-assign-swap (list->vector pins))))))

(evaluate terminal-sketch TS)

;; Now let's see if we can synthesize a clause
(define stmt-sketch
  (stmt?? 0 3))

(define SS
  (synthesize
   #:forall pins
   #:guarantee (assert (equal? (car (arduino-sem:interpret stmt-sketch (list->vector pins) (list->vector refs)))
                               (multi-assign-swap (list->vector pins))))))

(evaluate stmt-sketch SS)
  



