#lang rosette

(require (prefix-in arduino: "arduino/syntax.rkt")
         (prefix-in arduino-sem: "arduino/semantics.rkt")
         "arduino/inversion.rkt"
         (prefix-in unity: "unity/syntax.rkt")
         (prefix-in unity-sem: "unity/semantics.rkt")
         rosette/lib/synthax)

;; Synthesize an equivalent to a multi-assignment swap

;; Type environments
(define arduino-env (cons '(0) (cons '(0 1) '(0 1))))

(define swap-prog
  (unity:unity*
   (list (unity:declare* 0 'readwrite)
         (unity:declare* 1 'readwrite))
   (unity:multi-assignment* '()
                            '())
   (list (unity:assign* #t
                        (unity:multi-assignment*
                         (list 0 1)
                         (list (unity:ref* 1)
                               (unity:ref* 0)))))))

(define-symbolic left right aux boolean?)

(define vars (list (cons 0 left)
                   (cons 1 right)))

(define pins (list left right))
(define refs (list aux))

;; First we see if we can find an assignment of concrete terminal

(define terminal-sketch
  (arduino:seq* (arduino:set!* (??) (arduino:read* (??)))
                (arduino:seq* (arduino:write!* (??) (arduino:read* (??)))
                              (arduino:seq* (arduino:write!* (??) (arduino:ref* (??)))
                                            null))))

(define terminal-synth
  (synthesize
   #:forall pins
   #:guarantee (assert
                (equal?
                 (car (arduino-sem:interpret terminal-sketch
                                             arduino-env
                                             (list->vector pins)
                                             (list->vector refs)))
                 (let ([rstate (unity-sem:interpret-unity-assign swap-prog
                                                                 vars)])
                   (vector (unity-sem:state-get 0 rstate)
                           (unity-sem:state-get 1 rstate)))))))

(evaluate terminal-sketch terminal-synth)

;; Now let's see if we can synthesize a clause

(define stmt-sketch
  (stmt?? 0 3))

(define stmt-synth
  (synthesize
   #:forall pins
   #:guarantee (assert
                (equal?
                 (car (arduino-sem:interpret stmt-sketch
                                             arduino-env
                                             (list->vector pins)
                                             (list->vector refs)))
                 (let ([rstate (unity-sem:interpret-unity-assign swap-prog
                                                                 vars)])
                   (vector (unity-sem:state-get 0 rstate)
                           (unity-sem:state-get 1 rstate)))))))

(evaluate stmt-sketch stmt-synth)
  



