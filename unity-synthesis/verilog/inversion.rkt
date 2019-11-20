#lang rosette

(require "state.rkt"
         "syntax.rkt"
         "context.rkt"
         "semantics.rkt"
         rosette/lib/angelic
         rosette/lib/synthax)

;; An expression is a tree-like structure. We constrain it with a depth.
;; At any depth, we can have terminals. Those are determined by the context
;; and the set of literals (in our case, 0 and 1)
(define (exp?? depth cxt)
  (define (add-terminals stub cxt)
    (match cxt
      [(context* _ _ wires regs)
       (let ([read-names (append wires regs)])
         (if (null? read-names)
             ;; There are no names in the context we can derive values from
             (apply choose* stub)
             ;; Add val* with read-names to the list of potential productions
             (apply choose*
                    (val* (apply choose* read-names))
                    stub)))]))

  ;; Base case: only permit literals + terminals
  (add-terminals (if (positive? depth)
                     (list 'one
                           'zero
                           (not* (exp?? (- depth 1) cxt))
                           ((choose* and*
                                     or*
                                     eq*
                                     neq*)
                            (exp?? (- depth 1) cxt)
                            (exp?? (- depth 1) cxt)))
                     (list 'one
                           'zero))
                 cxt))
  
;; (define-symbolic A B boolean?)

;; (let* ([cxt (context* (list 'a 'b)
;;                       '()
;;                       (list 'a 'b)
;;                       '())]
;;        [state (list (cons 'a A)
;;                     (cons 'b B))]
;;        [sketch (exp?? 1 cxt)]
;;        [synth (synthesize
;;                #:forall state
;;                #:guarantee
;;                (assert
;;                 (eq?
;;                  (eval sketch cxt state)
;;                  (xor A B))))])
;;   (evaluate sketch synth))

;; A statement is a list structure of trees: Each non-null node of the list
;; is an if* or <=* statement, which may have their own sub statements or
;; sub expressions.
(define (stmt?? depth sub-exp-depth sub-stmt-depth cxt)
  (if (positive? depth)
      (let ([if-production
             (if* (exp?? sub-exp-depth cxt)
                  ;; then clause
                  (stmt?? sub-stmt-depth
                          sub-exp-depth
                          (- sub-stmt-depth 1)
                          cxt)
                  ;; else clause
                  (stmt?? sub-stmt-depth
                          sub-exp-depth
                          (- sub-stmt-depth 1)
                          cxt))]
            [tail
             (stmt?? (- depth 1)
                     sub-exp-depth
                     sub-stmt-depth
                     cxt)])   
        (match cxt
          ;; No writable names in the context.
          ;; Admittedly, this is kind of a silly situation to be
          ;; in, but hey, them's the breaks.
          [(context* _ _ _ '())
           (choose* '()
                    (cons if-production
                          tail))]
          [(context* _ _ _ write-names)
           (choose* '()
                    (cons (choose*
                           if-production
                           (<=* (apply choose* write-names)
                                (exp?? sub-exp-depth cxt)))
                          tail))]))
      '()))

;; (define-symbolic A B C D boolean?)

;; (let* ([cxt (context* (list 'a 'b)
;;                       (list 'c 'd)
;;                       (list 'a 'b)
;;                       (list 'c 'd))]
;;        [state (list (cons 'a A)
;;                     (cons 'b B))]
;;        [sketch (stmt?? 2 0 0 cxt)]
;;        [synth (synthesize
;;                #:forall state
;;                #:guarantee
;;                (assert
;;                 (eq?
;;                  (verilog-sem:interpret-stmt sketch cxt state)
;;                  (cons (cons 'd A)
;;                        (cons (cons 'c B)
;;                              state)))))])
;;   (evaluate sketch synth))

;; TODO: Inversion of I/O and type-declaration statements

(provide exp??
         stmt??)
