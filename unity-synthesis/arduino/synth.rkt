#lang rosette

(require "../util.rkt"
         "environment.rkt"
         "semantics.rkt"
         "syntax.rkt"
         (prefix-in unity: "../unity/environment.rkt")
         (prefix-in unity: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         ;;"inversion.rkt"
         rosette/lib/synthax)

(define max-expression-depth
  5)

(define max-declaration-depth
  10)

(define max-pin-id
  21)

(define (symbolic-state context)
  (define (symbolic-boolean)
    (define-symbolic* x boolean?)
    x)

  (define (helper cxt st)
    (match cxt
      ['() st]
      [(cons (cons id 'bool) tail)
       (helper tail
               (cons (cons id (symbolic-boolean))
                     st))]
      [(cons (cons id 'pin-in) tail)
       (helper tail
               (cons (cons id (level* (symbolic-boolean)))
                     st))]
      [(cons (cons id 'pin-out) tail)
       (helper tail
               (cons (cons id (level* (symbolic-boolean)))
                     st))]))

  (helper context '()))

(define (arduino-to-unity-map unity-cxt)
  (define (next-pin-id current)
    (if (>= current max-pin-id)
        (error "insufficient pins to map context")
        (+ 1 current)))

  (define (digital-pin id)
    (string->symbol (format "d~a" id)))

  (define (state-mapper state-map state)
    (match state-map
      ['() '()]
      [(cons (cons id fn) tail)
       (cons (cons id (fn state))
             (state-mapper tail state))]))
  
  (define (helper unity-cxt arduino-cxt state-map current-pin)
    (match unity-cxt
      ['() (values arduino-cxt
                   (lambda (st) (state-mapper state-map st)))]
      [(cons (cons id 'boolean) tail)
       (helper tail
               (cons (cons id 'bool)
                     arduino-cxt)
               (cons (cons id
                           (lambda (st)
                             (get-mapping id st)))
                     state-map)
               current-pin)]
      [(cons (cons id 'channel) tail)
       (let* ([req-pin current-pin]
              [ack-pin (next-pin-id req-pin)]
              [val-pin (next-pin-id ack-pin)]
              [req-id (digital-pin req-pin)]
              [ack-id (digital-pin ack-pin)]
              [val-id (digital-pin val-pin)])
         (helper tail
                 (append (list (cons req-id 'pin-out)
                               (cons ack-id 'pin-out)
                               (cons val-id 'pin-out))
                         arduino-cxt)
                 (cons (cons id
                             (lambda (st)
                               (let ([req-v (get-mapping req-id st)]
                                     [ack-v (get-mapping ack-id st)]
                                     [val-v (get-mapping val-id st)])
                                 (if (eq? req-v ack-v)
                                     (unity:channel* #f null)
                                     (unity:channel* #t (level*-val val-v))))))
                       state-map)
                 val-pin))]))

  (helper unity-cxt '() '() 0))

(let*-values ([(unity-cxt) (list (cons 'a 'boolean)
                                 (cons 'b 'boolean)
                                 (cons 'c 'channel))]
              [(cxt st-map) (arduino-to-unity-map unity-cxt)]
              [(st) (symbolic-state cxt)])
             (st-map st))

;; VVV OUTDATED VVV
;; The Arduino model admits two different sorts of mutable references:
;; variables and pins. Variables are used for internal state, and pins
;; are used for external state (input/output). UNITY has no such
;; distinction, although we could refine the language to allow for
;; one.
;;
;; The current strategy for showing equivalence is to say that a
;; mapping exists between each UNITY reference and an Arduino pin. We
;; say that two programs are equivalent if interpreting them given
;; equivalent initial states produces equivalent subsequent states.
;;
;; If we have a UNITY symbolic state, we need to derive an equivalent
;; Arduino symbolic state. That's what this function is for. It does
;; this in two steps:
;;
;; Transforms a UNITY program and returns a pair:
;; 1) The arduino context
;; 2) A function from a UNITY state to an Arduino state
;; representation.
;; (define (unity-to-arduino-env prog)
;;   (define (unity-ref-list pin pin-limit unity-state mapping)
;;     (if (>= pin pin-limit)
;;         '()
;;         (let ([id (cdr (assoc pin mapping))])
;;           (cons (unity-sem:state-get id unity-state)
;;                 (unity-ref-list (+ 1 pin)
;;                                 pin-limit
;;                                 unity-state
;;                                 mapping)))))
  
;;   (define (unity-declare-to-arduino-env declare cxt mapping pin)
;;     (if (pair? declare)
;;         (match cxt
;;           [(context* vars
;;                      read-pins
;;                      write-pins)
;;            (match (car declare)
;;              [(unity:declare* id 'read)
;;               (unity-declare-to-arduino-env (cdr declare)
;;                                             (context* vars
;;                                                       (cons pin read-pins)
;;                                                       write-pins)
;;                                             (cons (cons pin id)
;;                                                   mapping)
;;                                             (+ 1 pin))]
;;              [(unity:declare* id _)
;;               (unity-declare-to-arduino-env (cdr declare)
;;                                             (context* vars
;;                                                       (cons pin read-pins)
;;                                                       (cons pin write-pins))
;;                                             (cons (cons pin id)
;;                                                   mapping)
;;                                             (+ 1 pin))])])
;;           (cons cxt
;;                 (lambda (unity-state)
;;                   (state* empty-vector
;;                           (list->vector (unity-ref-list 0 pin unity-state mapping)))))))
  
;;   (match prog
;;     [(unity:unity* declare _ _)
;;      (if (> (length declare) max-pin-id)
;;          'allocerr
;;          (unity-declare-to-arduino-env declare empty-context '() 0))]))

;; ;; Synthesizes a sequence of Arduino declaration statments
;; ;; that produces an equivalent arduino state environment
;; (define (decl-synth prog)
;;   (let ([arduino-cxt (car (unity-to-arduino-env prog))])
    
;;     (define (param-decl-synth sketch)
;;       (let ([unity-state (unity-symbolic-state prog)])
;;         (synthesize
;;          #:forall unity-state
;;          #:guarantee (assert
;;                       (equal?
;;                        (arduino-sem:interpret-decl sketch)
;;                        arduino-cxt)))))

;;     (define (try-synth depth)
;;       (if (> depth max-declaration-depth)
;;           'decl-depth-exceeded
;;           (let* ([sketch (decl?? depth arduino-cxt)]
;;                  [synth (param-decl-synth sketch)])
;;             (if (eq? synth (unsat))
;;                 (try-synth (+ 1 depth))
;;                 (evaluate sketch synth)))))

;;     (try-synth 0)))

;; ;; Synthesizes a sequence of Arduino statements equivalent to
;; ;; a UNITY multi-assignment, given an optional Arduino implementation
;; ;; of a guarded expression
;; (define (multi-synth guard-impl multi prog)
;;   (let* ([arduino-env (unity-to-arduino-env prog)]
;;          [arduino-cxt (car arduino-env)]
;;          [unity-to-arduino-state (cdr arduino-env)])
    
;;     (define (param-guarded-multi-synth sketch)
;;       (let ([unity-state (unity-symbolic-state prog)]
;;             [unity-cxt (unity-sem:interpret-unity-declare prog)])
;;         (synthesize
;;          #:forall unity-state
;;          #:assume (arduino-sem:evaluate guard-impl
;;                                         arduino-cxt
;;                                         (unity-to-arduino-state unity-state))
;;          #:guarantee (let ([arduino-next-state
;;                             (arduino-sem:interpret sketch
;;                                                    arduino-cxt
;;                                                    (unity-to-arduino-state unity-state))]
;;                            [unity-next-state
;;                             (unity-sem:interpret-multi
;;                              multi
;;                              unity-cxt
;;                              unity-state)])
;;                        (assert
;;                         (equal? (state-pins arduino-next-state)
;;                                 (state-pins (unity-to-arduino-state unity-next-state))))))))

;;     (define (try-synth exp-depth stmt-depth)
;;       (if (> exp-depth max-expression-depth)
;;           'exp-depth-exceeded
;;           (let* ([sketch (stmt?? exp-depth stmt-depth arduino-cxt)]
;;                  [synth (param-guarded-multi-synth sketch)])
;;             (if (eq? synth (unsat))
;;                 (try-synth (+ 1 exp-depth) stmt-depth)
;;                 (evaluate sketch synth)))))

;;     (match multi
;;       [(unity:multi-assignment* vs es)
;;        (let ([assignment-count (length vs)])
;;          (try-synth 0 assignment-count))])))

;; ;; Synthesize an entire Arduino program from a UNITY spec
;; (define (synthesize-arduino-program unity-program)
;;   (let* ([unity-state (unity-symbolic-state unity-program)]
;;          [unity-cxt (unity-sem:interpret-unity-declare unity-program)]
;;          [arduino-env (unity-to-arduino-env unity-program)]
;;          [arduino-cxt (car arduino-env)]
;;          [unity-to-arduino-state (cdr arduino-env)])

;;     (define (assign-synth sketch)
;;       (synthesize
;;        #:forall unity-state
;;        #:guarantee (let ([arduino-next-state
;;                           (arduino-sem:interpret sketch
;;                                                  arduino-cxt
;;                                                  (unity-to-arduino-state unity-state))]
;;                          [unity-next-state
;;                           (unity-sem:interpret-unity-assign unity-program
;;                                                             unity-state)])
;;                      (assert
;;                       (equal? (state-pins arduino-next-state)
;;                               (state-pins (unity-to-arduino-state unity-next-state)))))))

;;     (define (try-synth guard-count assign-count exp-depth)
;;       (if (> exp-depth max-expression-depth)
;;           'exp-depth-exceeded
;;           (let* ([sketch (guarded-stmt?? guard-count assign-count exp-depth arduino-cxt)]
;;                  [synth (assign-synth sketch)])
;;             (if (eq? synth (unsat))
;;                 (try-synth guard-count assign-count (+ 1 exp-depth))
;;                 (evaluate sketch synth)))))

;;   (match unity-program
;;     [(unity:unity* declare initially assign)
;;      (let* ([declare-impl (decl-synth unity-program)]
;;             [initially-impl (multi-synth 'true initially unity-program)]
;;             [guard-clauses (length assign)]
;;             [writable-pins (length (context-writable-pins arduino-cxt))]
;;             [assign-impl (try-synth guard-clauses writable-pins 0)])
;;        (arduino*
;;         (setup*
;;          (append declare-impl
;;                  initially-impl))
;;         (loop*
;;          assign-impl)))])))

;; (provide synthesize-arduino-program)

;; ;; Synthesis playground follows...
;; ;; (define-symbolic var-a var-b boolean?)

;; ;; (define state (list->vector (list var-a)))

;; ;; (define env
;; ;;   (cons (list 'tmp)
;; ;;         (cons (list 0)
;; ;;               (list 0))))

;; ;; (define sketch
;; ;;   (stmt? 0 1 env))

;; ;; (define synth
;; ;;   (synthesize
;; ;;    #:forall state
;; ;;    #:guarantee (assert
;; ;;                 (equal?
;; ;;                  (car (interpret sketch
;; ;;                                  env
;; ;;                                  state
;; ;;                                  empty-vector))
;; ;;                  (vector #t)))))

;; ;; (evaluate sketch synth)
