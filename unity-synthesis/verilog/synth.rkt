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
(define default-inputs '(reset clock))
(define default-wires '(reset clock))

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

;; Given a verilog context and the unity context and symbolic state,
;; generate a verilog symbolic state that uses the unity symbolic state
;; for variables shared between the two, and generates new symbolic values
;; for any exclusive variables.
(define (verilog-symbolic-state verilog-cxt unity-cxt unity-state)
  (define (new-sym)
    (define-symbolic* x boolean?)
    x)

  (define (helper vars unity-vars unity-state)
    (if (null? vars)
        '()
        (let* ([var (car vars)]
               [sym-val (if (in-list? var unity-vars)
                            (unity-sem:state-get var unity-state)
                            (new-sym))])
          (cons (cons var sym-val)
                (helper (cdr vars) unity-vars unity-state)))))

  (match verilog-cxt
    [(context* _ _ wires regs)
     (helper (remove-duplicates (append wires regs))
             (remove-duplicates (append (car unity-cxt)
                                        (cdr unity-cxt)))
             unity-state)]))

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
          (read-helper read-cxt default-inputs out default-wires reg))
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

(define (synthesize-expression unity-exp unity-cxt verilog-cxt unity-state verilog-state)
  (define (try-synth depth)
    (if (> depth max-expression-depth)
        'exp-depth-exceeded
        (let* ([sketch (exp?? depth verilog-cxt)]
               [synth (synthesize
                       #:forall unity-state
                       #:guarantee
                       (assert
                        (eq? (unity-sem:evaluate unity-exp unity-cxt unity-state)
                             (eval sketch verilog-cxt verilog-state))))])
          (if (eq? synth (unsat))
              (try-synth (+ 1 depth))
              (evaluate sketch synth)))))

  (try-synth 0))

(define (synthesize-multi-assignment unity-multi unity-cxt verilog-cxt unity-state verilog-state assume)
  (define (try-synth exp-depth stmt-depth)
    (if (> exp-depth max-expression-depth)
        'exp-depth-exceeded
        (let* ([sketch (stmt?? stmt-depth exp-depth 0 verilog-cxt)]
               [synth (synthesize
                       #:forall unity-state
                       #:assume assume
                       #:guarantee
                       (let ([unity-next-state (unity-sem:interpret-multi unity-multi
                                                                     unity-cxt
                                                                     unity-state)]
                             [verilog-next-state (interpret-stmt sketch
                                                            verilog-cxt
                                                            verilog-state)])
                         (assert
                          (unity-verilog-state-eq? unity-cxt
                                                   verilog-cxt
                                                   unity-next-state
                                                   verilog-next-state))))])
          (if (eq? synth (unsat))
              (try-synth (+ 1 exp-depth) stmt-depth)
              (evaluate sketch synth)))))

  (match unity-multi
    [(unity:multi-assignment* vars _)
     (let ([assignment-count (length vars)])       
       (try-synth 0 assignment-count))]))

(define (synthesize-assign unity-assign unity-cxt verilog-cxt unity-state verilog-state)
  (define (single-assign assign)
    (match assign
      [(unity:assign* guard multi)
       (let* ([verilog-guard (synthesize-expression guard
                                                    unity-cxt
                                                    verilog-cxt
                                                    unity-state
                                                    verilog-state)]
              [guard-assertion (eval verilog-guard verilog-cxt verilog-state)]
              [verilog-multi (synthesize-multi-assignment multi
                                                          unity-cxt
                                                          verilog-cxt
                                                          unity-state
                                                          verilog-state
                                                          guard-assertion)])
         (if* verilog-guard verilog-multi '()))]))

  (if (null? unity-assign)
      '()
      (cons (single-assign (car unity-assign))
            (synthesize-assign (cdr unity-assign) unity-cxt verilog-cxt unity-state verilog-state))))

(define (generate-externals cxt)
  (match cxt
    [(context* in out _ _) (append in out)]))

(define (generate-io-constraints cxt)
  (match cxt
    [(context* in out _ _)
     (append (map input* in)
             (map output* out))]))

(define (generate-type-declarations cxt)
  (match cxt
    [(context* _ _ wires regs)
     (append (map wire* wires)
             (map reg* regs))]))

(define (synthesize-program unity-program name)
  (match unity-program
    [(unity:unity* declare
                   initially
                   assign)
     (let* ([unity-cxt (unity-sem:interpret-declare declare)]
            [verilog-cxt (unity-to-verilog-cxt unity-cxt)]
            [externals (generate-externals verilog-cxt)]
            [io-constraints (generate-io-constraints verilog-cxt)]
            [type-declarations (generate-type-declarations verilog-cxt)]
            [unity-state (unity-symbolic-state unity-program)]
            [verilog-state (verilog-symbolic-state verilog-cxt unity-cxt unity-state)])
       (module* name externals
         io-constraints
         type-declarations
         (always* (list (posedge* 'clk) (posedge* 'reset))
                  (list (if* (val* 'reset)
                             (synthesize-multi-assignment initially
                                                          unity-cxt
                                                          verilog-cxt
                                                          unity-state
                                                          verilog-state
                                                          #t)
                             (synthesize-assign assign
                                                unity-cxt
                                                verilog-cxt
                                                unity-state
                                                verilog-state))))))]))

(provide synthesize-program)
