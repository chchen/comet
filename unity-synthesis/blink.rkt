#lang rosette

(require "arduino/synth.rkt"
         "unity/syntax.rkt"
         "verilog/synth.rkt"
         (prefix-in arduino: "arduino/syntax.rkt")
         (prefix-in verilog: "verilog/syntax.rkt"))

;; Synthesize an equivalent to two-input asynchronous parity function
(define blink-prog
  (unity*
   (list (declare* 'digital_6 'readwrite))
   (multi-assignment* (list 'digital_6)
                      (list #f))
   (list (assign* #t
                  (multi-assignment* (list 'digital_6)
                                     (list (not* (ref* 'digital_6))))))))

(define (pretty-print tree)
  (define (pp-helper tree indent)
    (if (null? tree)
        '()
        (if (pair? (car tree))
            (append (pp-helper (car tree) (string-append indent "  "))
                    (pp-helper (cdr tree) indent))
            (if (null? (car tree))
                (pp-helper (cdr tree) indent)
                (cons (string-append indent (car tree))
                      (pp-helper (cdr tree) indent))))))

  (pp-helper tree ""))

;; For Arduino
(arduino:emit-program (prog-synth blink-prog))

;; For Verilog
(verilog:emit-module (synthesize-verilog-program blink-prog 'blink))    
