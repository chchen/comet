#lang rosette

(require "../unity/synth.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity-sem: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         "validate.rkt"
         rosette/lib/synthax)

(define max-expression-depth
  5)

(define max-declaration-depth
  10)

(define empty-vector
  (list->vector '()))

;; Transforms a UNITY declaration clause and returns a pair:
;; 1) The arduino environment
;; 2) A procedure that takes a unity state and returns the appropriate
;;  arduino state vector
(define (unity-to-arduino-env prog)
  (define (unity-ref-list pin limit state mapping)
    (if (>= pin limit)
        '()
        (let ([id (cdr (assoc pin mapping))])
          (cons (unity-sem:state-get id state)
                (unity-ref-list (+ 1 pin)
                                limit
                                state
                                mapping)))))
  
  (define (unity-declare-to-arduino-env declare v-env r-env w-env mapping pin)
    (if (pair? declare)
        (match (car declare)
          [(unity:declare* id 'read)
           (unity-declare-to-arduino-env (cdr declare)
                                         v-env
                                         (cons pin r-env)
                                         w-env
                                         (cons (cons pin id)
                                               mapping)
                                         (+ 1 pin))]
          [(unity:declare* id _)
           (unity-declare-to-arduino-env (cdr declare)
                                         v-env
                                         (cons pin r-env)
                                         (cons pin w-env)
                                         (cons (cons pin id)
                                               mapping)
                                         (+ 1 pin))])
        (cons (cons v-env
                    (cons r-env w-env))
              (lambda (state)
                (list->vector (unity-ref-list 0 pin state mapping))))))
  
  (match prog
    [(unity:unity* declare _ _)
     (if (> (length declare) 14)
         'allocerr
         (unity-declare-to-arduino-env declare '() '() '() '() 0))]))

;; Synthesizes a sequence of Arduino declaration statments
;; that produces an equivalent arduino state environment
(define (decl-synth prog)
  (let* ([arduino-mapping (unity-to-arduino-env prog)]
         [arduino-env (car arduino-mapping)])
    
    (define (param-decl-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)])
        (synthesize
         #:forall unity-state
         #:guarantee (assert
                      (equal?
                       (interpret-decl sketch)
                       arduino-env)))))

    (define (try-synth depth)
      (if (> depth max-declaration-depth)
          'decl-depth-exceeded
          (let* ([sketch (decl?? depth arduino-env)]
                 [synth (param-decl-synth sketch)])
            (if (eq? synth (unsat))
                (try-synth (+ 1 depth))
                (evaluate sketch synth)))))

    (try-synth 0)))

;; Synthesizes an Arduino boolean expression equivalent to the
;; given UNITY guard
(define (guard-synth guard prog)
  (let* ([arduino-mapping (unity-to-arduino-env prog)]
         [arduino-env (car arduino-mapping)]
         [state-transform (cdr arduino-mapping)])
    
    (define (param-guard-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)]
            [unity-env (unity-sem:interpret-unity-declare prog)])
        (synthesize
         #:forall unity-state
         #:guarantee (assert
                      (equal?
                       (eval sketch
                             arduino-env
                             (state-transform unity-state)
                             empty-vector)
                       (unity-sem:evaluate
                        guard
                        unity-env
                        unity-state))))))

    (define (try-synth depth)
      (if (> depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([sketch (exp?? depth arduino-env)]
                 [synth (param-guard-synth sketch)])
            (if (eq? synth (unsat))
                (try-synth (+ 1 depth))
                (evaluate sketch synth)))))

    (try-synth 0)))

;; Synthesizes a sequence of Arduino statements equivalent to
;; a UNITY multi-assignment, given an optional Arduino implementation
;; of a guarded expression
(define (multi-synth guard-impl multi prog)
  (let* ([arduino-mapping (unity-to-arduino-env prog)]
         [arduino-env (car arduino-mapping)]
         [state-transform (cdr arduino-mapping)])
    
    (define (param-guarded-multi-synth sketch)
      (let ([unity-state (unity-symbolic-state prog)]
            [unity-env (unity-sem:interpret-unity-declare prog)])
        (synthesize
         #:forall unity-state
         #:assume (eval guard-impl
                        arduino-env
                        (state-transform unity-state)
                        empty-vector)
         #:guarantee (assert
                      (equal?
                       (car (interpret sketch
                                       arduino-env
                                       (state-transform unity-state)
                                       empty-vector))
                       (let ([next-state
                              (unity-sem:interpret-multi
                               multi
                               unity-env
                               unity-state)])
                         (state-transform next-state)))))))

    (define (try-synth exp-depth stmt-depth)
      (if (> exp-depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([sketch (stmt?? exp-depth stmt-depth arduino-env)]
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
         (seq*
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
       (seq-append (decl-synth prog)
                   (multi-synth 'true initially prog)))
      (loop*
       (assign-synth assign prog)))]))

(provide assign-synth
         decl-synth
         guard-synth
         multi-synth
         prog-synth
         unity-to-arduino-env
         empty-vector)

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
