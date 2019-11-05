#lang rosette

(require "../util.rkt")

;; Definitions regarding type context handling

;; At the moment, all values are of type boolean. However, names can be
;; exposed to external modules as input or output. Furthermore, names can
;; be set as wire or reg types. Wires can be thought of as "binding" a
;; name to some external data storage element. Regs can be thought of as
;; actual data storage elements. When two modules are composed, reg
;; outputs from one can be connected to wire inputs in the other. This
;; means that input/output and wire/reg are not orthogonal: an input must
;; be a wire and an output must be a reg. If we are to define an internal
;; name, and we wish to write to it, it must be a reg.

;; We define a context

(require "syntax.rkt")

(struct context* (inputs
                  outputs
                  wires
                  regs)
  #:transparent)

(define (is-wire? v cxt)
  (match cxt
    [(context* in out wire reg) (in-list? v wire)]
    [_ #f]))

(define (is-reg? v cxt)
  (match cxt
    [(context* in out wire reg) (in-list? v reg)]
    [_ #f]))

(define (can-read? v cxt)
  (or (is-wire? v cxt)
      (is-reg? v cxt)))

(define (can-write? v cxt)
  (is-reg? v cxt))

(define (parse-io-constraints constraints externals inputs outputs)
  (match constraints
    ['() (cons inputs outputs)]
    [(cons (input* i) tail)
     (if (in-list? i externals)
         (parse-io-constraints tail
                               externals
                               (cons i inputs)
                               outputs)
         'err)]
    [(cons (output* o) tail)
     (if (in-list? o externals)
         (parse-io-constraints tail
                              externals
                              inputs
                              (cons o outputs))
         'err)]
    [_ 'err]))

(define (parse-type-declarations declarations inputs outputs wires regs)
  (match declarations
    ['() (cons wires regs)]
    [(cons (reg* r) tail)
     (if (in-list? r inputs)
         'err
         (parse-type-declarations tail
                                  inputs
                                  outputs
                                  wires
                                  (cons r regs)))]
    [(cons (wire* w) tail)
     (if (in-list? w outputs)
         'err
         (parse-type-declarations tail
                                  inputs
                                  outputs
                                  (cons w wires)
                                  regs))]
    [_ 'err]))

(define (parse-context verilog-module)
  (match verilog-module
    [(module* _ externals io-constraints type-declarations _)
     (let* ([ins-outs (parse-io-constraints io-constraints externals '() '())]
            [ins (car ins-outs)]
            [outs (cdr ins-outs)]
            [wires-regs (parse-type-declarations type-declarations ins outs '() '())]
            [wires (car wires-regs)]
            [regs (cdr wires-regs)])
       (context* ins outs wires regs))]
    [_ 'err]))

(provide context*
         is-wire?
         is-reg?
         can-read?
         can-write?
         parse-context)

;; Quick check: parse context

(let ([test-module
       (module* 'foo
           (list 'clock 'input 'output)
         (list (input* 'clock)
               (input* 'input)
               (output* 'output))
         (list (wire* 'clock)
               (wire* 'input)
               (reg* 'output))
         '())])
  (assert (eq?
           (parse-context test-module)
           (context* (list 'input 'clock)
                     (list 'output)
                     (list 'input 'clock)
                     (list 'output)))))
                       
