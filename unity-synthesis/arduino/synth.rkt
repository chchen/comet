#lang rosette

(require "../unity/synth.rkt"
         "environment.rkt"
         (prefix-in arduino-sem: "semantics.rkt")
         "syntax.rkt"
         (prefix-in unity-sem: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         rosette/lib/synthax)

(define max-expression-depth
  5)

(define max-declaration-depth
  10)

(define max-pin-id
  14)

(define empty-vector
  (list->vector '()))

;; Transforms a UNITY declaration clause and returns a pair:
;; 1) The arduino context
;; 2) A procedure that takes a unity state and returns the appropriate
;;  arduino state vector
(define (unity-to-arduino-env prog)
  (define (unity-ref-list pin pin-limit unity-state mapping)
    (if (>= pin pin-limit)
        '()
        (let ([id (cdr (assoc pin mapping))])
          (cons (unity-sem:state-get id unity-state)
                (unity-ref-list (+ 1 pin)
                                pin-limit
                                unity-state
                                mapping)))))
  
  (define (unity-declare-to-arduino-env declare cxt mapping pin)
    (if (pair? declare)
        (match cxt
          [(context* vars
                     read-pins
                     write-pins)
           (match (car declare)
             [(unity:declare* id 'read)
              (unity-declare-to-arduino-env (cdr declare)
                                            (context* vars
                                                      (cons pin read-pins)
                                                      write-pins)
                                            (cons (cons pin id)
                                                  mapping)
                                            (+ 1 pin))]
             [(unity:declare* id _)
              (unity-declare-to-arduino-env (cdr declare)
                                            (context* vars
                                                      (cons pin read-pins)
                                                      (cons pin write-pins))
                                            (cons (cons pin id)
                                                  mapping)
                                            (+ 1 pin))])])
          (cons cxt
                (lambda (unity-state)
                  (state* empty-vector
                          (list->vector (unity-ref-list 0 pin unity-state mapping)))))))
  
  (match prog
    [(unity:unity* declare _ _)
     (if (> (length declare) max-pin-id)
         'allocerr
         (unity-declare-to-arduino-env declare empty-context '() 0))]))

;; Synthesizes a sequence of Arduino declaration statments
;; that produces an equivalent arduino state environment
(define (decl-synth prog)
  (let ([arduino-cxt (car (unity-to-arduino-env prog))])
    
    (define (param-decl-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)])
        (synthesize
         #:forall unity-state
         #:guarantee (assert
                      (equal?
                       (arduino-sem:interpret-decl sketch)
                       arduino-cxt)))))

    (define (try-synth depth)
      (if (> depth max-declaration-depth)
          'decl-depth-exceeded
          (let* ([sketch (decl?? depth arduino-cxt)]
                 [synth (param-decl-synth sketch)])
            (if (eq? synth (unsat))
                (try-synth (+ 1 depth))
                (evaluate sketch synth)))))

    (try-synth 0)))

;; Synthesizes an Arduino boolean expression equivalent to the
;; given UNITY guard
(define (guard-synth guard prog)
  (let* ([arduino-env (unity-to-arduino-env prog)]
         [arduino-cxt (car arduino-env)]
         [unity-to-arduino-state (cdr arduino-env)])
    
    (define (param-guard-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)]
            [unity-cxt (unity-sem:interpret-unity-declare prog)])
        (synthesize
         #:forall unity-state
         #:guarantee (assert
                      (equal?
                       (arduino-sem:evaluate sketch
                                             arduino-cxt
                                             (unity-to-arduino-state unity-state))
                       (unity-sem:evaluate
                        guard
                        unity-cxt
                        unity-state))))))

    (define (try-synth depth)
      (if (> depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([sketch (exp?? depth arduino-cxt)]
                 [synth (param-guard-synth sketch)])
            (if (eq? synth (unsat))
                (try-synth (+ 1 depth))
                (evaluate sketch synth)))))

    (try-synth 0)))

;; Synthesizes a sequence of Arduino statements equivalent to
;; a UNITY multi-assignment, given an optional Arduino implementation
;; of a guarded expression
(define (multi-synth guard-impl multi prog)
  (let* ([arduino-env (unity-to-arduino-env prog)]
         [arduino-cxt (car arduino-env)]
         [unity-to-arduino-state (cdr arduino-env)])
    
    (define (param-guarded-multi-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)]
            [unity-cxt (unity-sem:interpret-unity-declare prog)])
        (synthesize
         #:forall unity-state
         #:assume (arduino-sem:evaluate guard-impl
                                        arduino-cxt
                                        (unity-to-arduino-state unity-state))
         #:guarantee (let ([arduino-next-state
                            (arduino-sem:interpret sketch
                                                   arduino-cxt
                                                   (unity-to-arduino-state unity-state))]
                           [unity-next-state
                            (unity-sem:interpret-multi
                             multi
                             unity-cxt
                             unity-state)])
                       (assert
                        (equal? (state-pins arduino-next-state)
                                (state-pins (unity-to-arduino-state unity-next-state))))))))

    (define (try-synth exp-depth stmt-depth)
      (if (> exp-depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([sketch (stmt?? exp-depth stmt-depth arduino-cxt)]
                 [synth (param-guarded-multi-synth sketch)])
            (if (eq? synth (unsat))
                (try-synth (+ 1 exp-depth) stmt-depth)
                (evaluate sketch synth)))))

    (match multi
      [(unity:multi-assignment* vs es)
       (let ([assignment-count (length vs)])
         (try-synth 0 assignment-count))])))

;; Synthesize a sequence of Arduino statements, each guarded with
;; a boolean expression, equivalent to a set of UNITY guarded multi-assignments
(define (assign-synth assigns prog)
  (if (pair? assigns)
      (match (car assigns)
        [(unity:assign* guard multi)
         (cons
          (let ([guard-impl (guard-synth guard prog)])
            (let ([multi-impl (multi-synth guard-impl multi prog)])
              (if* guard-impl
                   multi-impl)))
          (assign-synth (cdr assigns) prog))])
      '()))

;; Synthesize an entire program equivalent to a UNITY program
(define (prog-synth prog)
  (match prog
    [(unity:unity* declare initially assign)
     (arduino*
      (setup*
       (append (decl-synth prog)
                   (multi-synth 'true initially prog)))
      (loop*
       (assign-synth assign prog)))]))

(provide prog-synth)

;; Synthesis playground follows...
;; (define-symbolic var-a var-b boolean?)

;; (define state (list->vector (list var-a)))

;; (define env
;;   (cons (list 'tmp)
;;         (cons (list 0)
;;               (list 0))))

;; (define sketch
;;   (stmt? 0 1 env))

;; (define synth
;;   (synthesize
;;    #:forall state
;;    #:guarantee (assert
;;                 (equal?
;;                  (car (interpret sketch
;;                                  env
;;                                  state
;;                                  empty-vector))
;;                  (vector #t)))))

;; (evaluate sketch synth)
