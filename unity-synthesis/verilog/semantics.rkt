#lang rosette

(require "../util.rkt"
         "context.rkt"
         "state.rkt"
         "syntax.rkt"
         rosette/lib/match)

;; Build a verilog context from a program's preamble
(define (interpret-preamble io-constraints type-declarations)
  (define (helper preamble in out wire reg)
    (if (null? preamble)
        (context* in out wire reg)
        (match (car preamble)
          [(input* i) (helper (cdr preamble) (cons i in) out wire reg)]
          [(output* o) (helper (cdr preamble) in (cons o out) wire reg)]
          [(wire* w) (helper (cdr preamble) in out (cons w wire) reg)]
          [(reg* r) (helper (cdr preamble) in out wire (cons r reg))])))

  (helper (append io-constraints type-declarations) '() '() '() '()))

;; Evaluate an expression that yields a value
(define (eval exp cxt state)
  (match exp
    [(and* l r) (and (eval l cxt state)
                     (eval r cxt state))]
    [(or* l r) (or (eval l cxt state)
                   (eval r cxt state))]
    [(eq* l r) (eq? (eval l cxt state)
                    (eval r cxt state))]
    [(neq* l r) (not (eq? (eval l cxt state)
                          (eval r cxt state)))]
    [(not* e) (not (eval e cxt state))]
    [(val* s) (state-get s cxt state)]
    ['one #t]
    ['zero #f]
    [e e]))

;; (define-symbolic A B C D boolean?)

;; Quick check: De Morgan on an expression
;; (let* ([cxt (context* (list 'a 'b)
;;                       '()
;;                       (list 'a 'b)
;;                       '())]
;;        [state (list (cons 'a A)
;;                     (cons 'b B))])
;;   (verify
;;    (assert
;;     (eq? (eval (not* (and* (val* 'a)
;;                                (val* 'b)))
;;                    cxt
;;                    state)
;;          (eval (or* (not* (val* 'a))
;;                         (not* (val* 'b)))
;;                    cxt
;;                    state)))))

;; Evaluate a sequence of statements whose assignments
;; appear as atomic updates from some previous state
;; to a next state
(define (interpret-stmt-h stmt cxt prev-state next-state)
  (match stmt
    ['() next-state]
    [(cons s tail)
     (match s
       [(if* guard then-stmt else-stmt)
        (let* ([next-stmt (if (eval guard cxt prev-state)
                             then-stmt
                             else-stmt)]
               [if-result (interpret-stmt-h next-stmt cxt prev-state next-state)])
          (interpret-stmt-h tail cxt prev-state if-result))]
       [(<=* l r)
        (let* ([val (eval r cxt prev-state)]
               [store-result (state-put l val cxt next-state)])
          (interpret-stmt-h tail cxt prev-state store-result))]
       [_ 'stmt-err])]))

(define (interpret-stmt stmt cxt state)
  (interpret-stmt-h stmt cxt state state))

;; Quick check: assign input value to output conditionally
;; (let* ([cxt (context* (list 'input 'guard)
;;                       (list 'output)
;;                       (list 'input 'guard)
;;                       (list 'output 'internal))]
;;        [state (list (cons 'input A)
;;                     (cons 'output B)
;;                     (cons 'guard C)
;;                     (cons 'internal (not D)))]
;;        [end-state (interpret-stmt (list (if* (val* 'guard)
;;                                              (list (<=* 'output
;;                                                         (val* 'input)))
;;                                              (list (<=* 'output
;;                                                         (not* (val* 'input)))))
;;                                         (<=* 'internal
;;                                              (not* (val* 'internal))))
;;                                   cxt
;;                                   state)])
;;   (verify
;;    (assert
;;     (and (eq? (state-get 'output cxt end-state)
;;               (if C
;;                   (state-get 'input cxt state)
;;                   (not (state-get 'input cxt state))))
;;          (eq? (state-get 'internal cxt end-state)
;;               D)))))

;; Evaluate to see if a always block's sensitivity list
;; is triggered by events in the event list
(define (s-list-triggered? s-list events)
  (match s-list
    ['() #f]
    [(cons h tail) (or (in-list? h events)
                       (s-list-triggered? tail events))]
    [_ 's-list-err]))

;; Quick check: sensitivity list
;; (let ([s-list (list (posedge* 'clock)
;;                     (posedge* 'reset))])
;;   (verify
;;    (assert
;;     (and (s-list-triggered? s-list (list (posedge* 'clock)))
;;          (s-list-triggered? s-list (list (posedge* 'reset)))
;;          (s-list-triggered? s-list (list (posedge* 'clock)
;;                                          (posedge* 'reset)))
;;          (not (s-list-triggered? s-list (list (posedge* 'nop))))
;;          (not (s-list-triggered? s-list '()))))))

(define (interpret-always-blocks blocks cxt state events)
  (match blocks
    ['() state]
    [(cons (always* s-list
                    stmt)
           tail)
     (let ([next-state (if (s-list-triggered? s-list events)
                           (interpret-stmt stmt cxt state)
                           state)])
       (interpret-always-blocks tail cxt next-state events))]
    [_ 'always-err]))

;; Quick check: tiggered and untriggered always blocks
;; (let* ([cxt (context* (list 'input)
;;                       (list 'output)
;;                       (list 'input)
;;                       (list 'output))]
;;        [start-state (list (cons 'input A)
;;                     (cons 'output B))]
;;        [always-blocks (list (always* (list (posedge* 'clock))
;;                                      (list (<=* 'output
;;                                                 (val* 'input))))
;;                             (always* (list (posedge* 'reset))
;;                                      (list (<=* 'output 0))))]
;;        [after-clock (interpret-always-blocks always-blocks
;;                                              cxt
;;                                              start-state
;;                                              (list (posedge* 'clock)))]
;;        [after-reset (interpret-always-blocks always-blocks
;;                                              cxt
;;                                              start-state
;;                                              (list (posedge* 'reset)))]
;;        [after-nop (interpret-always-blocks always-blocks
;;                                            cxt
;;                                            start-state
;;                                            (list (posedge* 'nop)))])
;;   (verify
;;    (assert
;;     (and (eq? (state-get 'output cxt after-clock)
;;               (state-get 'input cxt start-state))
;;          (eq? (state-get 'output cxt after-reset)
;;               #f)
;;          (eq? (state-get 'output cxt after-nop)
;;               (state-get 'output cxt start-state))))))

;; Interpret a module given context, state, and list of triggering events
(define (interpret-module verilog-module state events)
  (match verilog-module
    [(module* _ _ in-outs wires-regs blocks)
     (let* ([cxt (interpret-preamble in-outs wires-regs)])
       (interpret-always-blocks blocks cxt state events))]
     [_ 'module-err]))

;; Quick check: fifo on clock tick

;; (define-symbolic A B boolean?)

;; (let* ([test-module
;;         (module*
;;             'test
;;             (list 'in 'out 'clock)
;;           (list (input* 'in)
;;                 (output* 'out)
;;                 (input* 'clock)
;;                 (input* 'reset))
;;           (list (wire* 'in)
;;                 (reg* 'out)
;;                 (wire* 'clock)
;;                 (wire* 'reset))
;;           (list (always* (list (posedge* 'clock) (posedge* 'reset))
;;                          (list (if* (val* 'reset)
;;                                     (list (<=* 'out
;;                                                'zero))
;;                                     (list (<=* 'out
;;                                                (val* 'in))))))))]
;;        [start-state (list (cons 'in A)
;;                           (cons 'out B))]
;;        [cxt (interpret-preamble (list (input* 'in)
;;                                       (output* 'out)
;;                                       (input* 'clock)
;;                                       (input* 'reset))
;;                                 (list (wire* 'in)
;;                                       (reg* 'out)
;;                                       (wire* 'clock)
;;                                       (wire* 'reset)))]
;;        [reset-state (interpret-module test-module
;;                                       (cons (cons 'reset #t)
;;                                             start-state)
;;                                       (list (posedge* 'reset)
;;                                             (posedge* 'clock)))]
;;        [clock-state (interpret-module test-module
;;                                       (cons (cons 'reset #f)
;;                                             start-state)
;;                                       (list (posedge* 'clock)))])
;;   (list reset-state clock-state))

(provide interpret-module
         interpret-preamble
         interpret-stmt
         eval)
