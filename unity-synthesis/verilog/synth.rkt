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

(define max-expression-depth 10)
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

(define (generate-externals cxt)
  (match cxt
    [(context* inputs outputs _ _) (append inputs outputs)]))

(define (generate-io-constraints cxt)
  (match cxt
    [(context* inputs outputs _ _)
     (append (map input* inputs)
             (map output* outputs))]))

(define (generate-type-declarations cxt)
  (match cxt
    [(context* _ _ wires regs)
     (append (map wire* wires)
             (map reg* regs))]))

(define (scaffold-module name verilog-cxt reset-sketch assign-sketch)
  (module* name (generate-externals verilog-cxt)
    (generate-io-constraints verilog-cxt)
    (generate-type-declarations verilog-cxt)
    (list (always* (list (posedge* 'clock))
                   (list (if* (not* (val* 'reset))
                              reset-sketch
                              assign-sketch))))))

(define (interpret-module-wrapper verilog-module state reset)
  (let ([reset-val (not reset)])
    (interpret-module verilog-module
                      (append (list (cons 'reset reset-val)
                                    (cons 'clock #t))
                              state)
                      (list (posedge* 'clock)))))

(define (synth-reset unity-program name)
  (let* ([unity-cxt (unity-sem:interpret-unity-declare unity-program)]
         [verilog-cxt (unity-to-verilog-cxt unity-cxt)]
         [unity-start (unity-symbolic-state unity-program)]
         [verilog-start (verilog-symbolic-state verilog-cxt unity-cxt unity-start)])

    (define (try-synth exp-depth assign-depth)
      (if (> exp-depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([reset-sketch (assignment?? assign-depth
                                             exp-depth
                                             verilog-cxt)]
                 [module (scaffold-module name
                                          verilog-cxt
                                          reset-sketch
                                          '())]
                 [unity-reset-state (unity-sem:interpret-unity-initially unity-program
                                                                         unity-start)]
                 [verilog-reset-state (interpret-module-wrapper module
                                                                verilog-start
                                                                #t)]
                 [synth (synthesize
                         #:forall unity-start
                         #:guarantee
                         (assert
                          (unity-verilog-state-eq? unity-cxt
                                                   verilog-cxt
                                                   unity-reset-state
                                                   verilog-reset-state)))])
            (if (eq? synth (unsat))
                (try-synth (+ 1 exp-depth) assign-depth)
                (evaluate reset-sketch synth)))))

    (match unity-program
      [(unity:unity* _ _ assignments)
       (let* ([num-write (length (cdr unity-cxt))])
         (try-synth 0 num-write))])))

(define (synthesize-verilog-program unity-program name)
  (let* ([unity-cxt (unity-sem:interpret-unity-declare unity-program)]
         [verilog-cxt (unity-to-verilog-cxt unity-cxt)]
         [unity-start (unity-symbolic-state unity-program)]
         [verilog-start (verilog-symbolic-state verilog-cxt unity-cxt unity-start)])

    (define (try-synth exp-depth assign-depth cond-depth reset-impl)
      (if (> exp-depth max-expression-depth)
          'exp-depth-exceeded
          (let* ([assign-sketch (guarded-stmt?? cond-depth
                                                exp-depth
                                                assign-depth
                                                verilog-cxt)]
                 [module (scaffold-module name
                                          verilog-cxt
                                          reset-impl
                                          assign-sketch)]
                 [unity-reset-state (unity-sem:interpret-unity-initially unity-program
                                                                         unity-start)]
                 [verilog-reset-state (interpret-module-wrapper module
                                                                verilog-start
                                                                #t)]
                 [unity-next-state (unity-sem:interpret-unity-assign unity-program
                                                                     unity-start)]
                 [verilog-next-state (interpret-module-wrapper module
                                                               verilog-start
                                                               #f)]
                 [synth (synthesize
                         #:forall unity-start
                         #:assume (unity-verilog-state-eq? unity-cxt
                                                           verilog-cxt
                                                           unity-reset-state
                                                           verilog-reset-state)
                         #:guarantee
                         (assert
                          (unity-verilog-state-eq? unity-cxt
                                                   verilog-cxt
                                                   unity-next-state
                                                   verilog-next-state)))])
            (if (eq? synth (unsat))
                (try-synth (+ 1 exp-depth) assign-depth cond-depth reset-impl)
                (evaluate module synth)))))

    (match unity-program
      [(unity:unity* _ _ assignments)
       (let* ([num-write (length (cdr unity-cxt))]
              [num-assignments (length assignments)]
              [reset-impl (synth-reset unity-program name)])
         (try-synth 0 num-write num-assignments reset-impl))])))

(provide synthesize-verilog-program)
