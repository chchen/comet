#lang rosette

(require "arduino/synth.rkt"
         "unity/syntax.rkt"
         "verilog/synth.rkt"
         (prefix-in arduino: "arduino/syntax.rkt")
         (prefix-in verilog: "verilog/syntax.rkt"))

;; Two agents, A and B, send a "data token" between each other
(define agent-a
  (unity*
   (list (declare* 'reqAB 'readwrite)
         (declare* 'ackAB 'read)
         (declare* 'reqBA 'read)
         (declare* 'ackBA 'readwrite))
   (multi-assignment* (list 'reqAB
                            'ackBA)
                      (list #t
                            #f))
   (list (assign* (and* (eq* (ref* 'reqAB)
                             (ref* 'ackAB))
                        (not* (eq* (ref* 'reqBA)
                                   (ref* 'ackBA))))
                  (multi-assignment* (list 'reqAB
                                           'ackBA)
                                     (list (not* (ref* 'ackAB))
                                           (ref* 'reqBA)))))))

(define agent-b
  (unity*
   (list (declare* 'reqAB 'read)
         (declare* 'ackAB 'readwrite)
         (declare* 'reqBA 'readwrite)
         (declare* 'ackBA 'read))
   (multi-assignment* (list 'ackAB
                            'reqBA)
                      (list #f
                            #f))
   (list (assign* (and* (not* (eq* (ref* 'reqAB)
                                   (ref* 'ackAB)))
                        (eq* (ref* 'reqBA)
                             (ref* 'ackBA)))
                  (multi-assignment* (list 'ackAB
                                           'reqBA)
                                     (list (ref* 'reqAB)
                                           (not* (ref* 'reqBA))))))))

;; For Arduino
(display
 (arduino:emit-program (prog-synth agent-a)))

;; For Verilog
(display
 (verilog:emit-module (synthesize-verilog-program agent-b 'agent_b)))
