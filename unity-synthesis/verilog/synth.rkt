#lang rosette

(require "../unity/synth.rkt"
         "../util.rkt"
         "context.rkt"
         "semantics.rkt"
         "state.rkt"
         "syntax.rkt"
         (prefix-in unity-sem: "../unity/semantics.rkt")
         (prefix-in unity: "../unity/syntax.rkt")
         "inversion.rkt"
         rosette/lib/synthax)

(define max-expression-depth 5)

;; Ensure that the unity and verilog state representations are equal up to
;; the unity context
(define (unity-verilog-state-eq? unity-cxt verilog-cxt unity-state verilog-state)
  (define (helper vars)
    (if (null? vars)
        #t
        (and (eq? (unity-sem:state-get (car vars)
                                       unity-state)
                  (state-get (car vars)
                             verilog-cxt
                             verilog-state))
             (helper (cdr vars)))))
  
  (helper (remove-duplicates (append (car unity-cxt)
                                     (cdr unity-cxt)))))

;; Given a UNITY context, generate a symbolic state representation
(define (verilog-symbolic-state cxt)
  (define (new-sym)
    (define-symbolic* x boolean?)
    x)

  (define (helper vars)
    (if (null? vars)
        '()
        (cons (cons (car vars)
                    (new-sym))
              (helper (cdr vars)))))

  (match cxt
    [(context* _ _ wire reg)
     (helper (remove-duplicates (append wire reg)))]))

;; Convert a UNITY context structure and convert it into a
;; Verilog context structure.
(define (unity-to-verilog-cxt unity-cxt)
  (define (read-helper read-cxt in out wire reg)
    (if (null? read-cxt)
        (context* in out wire reg)
        (let ([read-var (car read-cxt)])
          (if (or (in-list? read-var out)
                  (in-list? read-var reg))
              ;; The variable was already declared as an output or a reg
              (read-helper (cdr read-cxt) in out wire reg)
              ;; The variable is new, add it to input and wire
              (read-helper (cdr read-cxt)
                           (cons read-var in)
                           out
                           (cons read-var wire)
                           reg)))))
        
  (define (write-helper write-cxt out reg)
    (if (null? write-cxt)
        (let ([read-cxt (car unity-cxt)])
          (read-helper read-cxt '() out '() reg))
        (let ([write-var (car write-cxt)])
          (write-helper (cdr write-cxt)
                        (cons write-var out)
                        (cons write-var reg)))))
  
  (let ([write-cxt (cdr unity-cxt)])
    (write-helper write-cxt '() '())))

;; (define base-verilog-inputs (list 'clock 'reset))

;; (define (unity-to-verilog-cxt unity-prog)
;;   (define (context-builder decls inputs outputs wires regs)
;;     (if (null? decls)
;;         ;; We're done: return the completed context.
;;         (context* inputs
;;                   outputs
;;                   wires
;;                   regs)
;;         ;; Go down the declarations
;;         (match (car decls)
;;           [(unity:declare* ident 'read)
;;            (context-builder (cdr decls)
;;                             (cons ident inputs)
;;                             outputs
;;                             (cons ident wires)
;;                             regs)]
;;           [(unity:declare* ident 'write)
;;            (context-builder (cdr decls)
;;                             inputs
;;                             (cons ident outputs)
;;                             wires
;;                             (cons ident regs))]
;;           [(unity:declare* ident 'readwrite)
;;            (context-builder (cdr decls)
;;                             inputs
;;                             (cons ident outputs)
;;                             wires
;;                             (cons ident regs))])))
;;   (match unity-prog
;;     [(unity:unity* declarations _ _)
;;      (context-builder declarations
;;                       base-verilog-inputs
;;                       '()
;;                       base-verilog-inputs
;;                       '())]))

(define (synthesize-expression unity-exp unity-cxt verilog-cxt state)
  (define (try-synth depth)
    (if (> depth max-expression-depth)
        'exp-depth-exceeded
        (let* ([sketch (exp?? depth verilog-cxt)]
               [synth (synthesize
                       #:forall state
                       #:guarantee
                       (assert
                        (eq? (eval sketch verilog-cxt state)
                             (unity-sem:evaluate unity-exp unity-cxt state))))])
          (if (eq? synth (unsat))
              (try-synth (+ 1 depth))
              (evaluate sketch synth)))))

  (try-synth 0))

(define (synthesize-multi-assignment unity-multi unity-cxt verilog-cxt state assume)
  (define (try-synth exp-depth stmt-depth)
    (if (> exp-depth max-expression-depth)
        'exp-depth-exceeded
        (let* ([sketch (stmt?? stmt-depth exp-depth 0 verilog-cxt)]
               [synth (synthesize
                       #:forall state
                       #:assume #t
                       #:guarantee
                       (assert
                        (eq? (interpret-stmt sketch verilog-cxt state)
                             (unity-sem:interpret-multi unity-multi unity-cxt state))))])
          (if (eq? synth (unsat))
              (try-synth (+ 1 exp-depth) stmt-depth)
              (evaluate sketch synth)))))

  (match unity-multi
    [(unity:multi-assignment* vars _)
     (let ([assignment-count (length vars)])       
       (try-synth 0 assignment-count))]))

(define (synthesize-assign unity-assign unity-cxt verilog-cxt state)
  (define (single-assign assign)
    (match assign
      [(unity:assign* guard multi)
       (let* ([verilog-guard (synthesize-expression guard
                                                    unity-cxt
                                                    verilog-cxt
                                                    state)]
              [guard-assertion (eval verilog-guard verilog-cxt state)]
              [verilog-multi (synthesize-multi-assignment multi
                                                          unity-cxt
                                                          verilog-cxt
                                                          state
                                                          guard-assertion)])
         (if* verilog-guard verilog-multi '()))]))

  (if (null? unity-assign)
      '()
      (cons (single-assign (car unity-assign))
            (synthesize-assign (cdr unity-assign) unity-cxt verilog-cxt state))))

(define (generate-externals unity-declare)
  (if (null? unity-declare)
      '()
      (match (car unity-declare)
        [(unity:declare* symbol _)
         (cons symbol
               (generate-externals (cdr unity-declare)))])))

(define (generate-io-constraints unity-declare)
  (if (null? unity-declare)
      '()
      (match (car unity-declare)
        [(unity:declare* symbol mode)
         (let ([constraint (match mode
                             ['read (input* symbol)]
                             [_ (output* symbol)])])
           (cons constraint
                 (generate-io-constraints (cdr unity-declare))))])))

(define (generate-type-declarations unity-declare)
  (if (null? unity-declare)
      '()
      (match (car unity-declare)
        [(unity:declare* symbol mode)
         (let ([constraint (match mode
                             ['read (wire* symbol)]
                             [_ (reg* symbol)])])
           (cons constraint
                 (generate-type-declarations (cdr unity-declare))))])))

(define (synthesize-program unity-program name)
  (match unity-program
    [(unity:unity* declare
                   initially
                   assign)
     (let* ([unity-cxt (unity-sem:interpret-declare declare)]
            [externals (generate-externals declare)]
            [io-constraints (generate-io-constraints declare)]
            [type-declarations (generate-type-declarations declare)]
            [verilog-cxt (interpret-preamble io-constraints type-declarations)]
            [state (unity-symbolic-state unity-program)])
       (module* name
           externals
         io-constraints
         type-declarations
         (always* (list 'clk 'reset)
                  (list (if* 'reset
                             (synthesize-multi-assignment initially
                                                          unity-cxt
                                                          verilog-cxt
                                                          state
                                                          #t)
                             (synthesize-assign assign
                                                unity-cxt
                                                verilog-cxt
                                                state))))))]))

(provide synthesize-program)
