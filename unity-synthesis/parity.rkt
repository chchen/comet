#lang rosette

(require "arduino/synth.rkt"
         "unity/syntax.rkt"
         "verilog/synth.rkt")

;; Synthesize an equivalent to two-input asynchronous parity function
(define parity-prog
  (unity*
   (list (declare* 'a-req 'read)
         (declare* 'a-ack 'readwrite)
         (declare* 'a-data 'read)
         (declare* 'b-req 'read)
         (declare* 'b-ack 'readwrite)
         (declare* 'b-data 'read)
         (declare* 'out-req 'readwrite)
         (declare* 'out-ack 'read)
         (declare* 'out-data 'write))
   (multi-assignment* (list 'a-ack
                            'b-ack
                            'out-req)
                      (list #f #f #f))
   (list (assign*
          (and*
           (and* (eq* (not* (ref* 'a-req))
                      (ref* 'a-ack))
                 (eq* (not* (ref* 'b-req))
                      (ref* 'b-ack)))
           (eq* (ref* 'out-ack)
                (ref* 'out-req)))
          (multi-assignment* (list 'a-ack
                                   'b-ack
                                   'out-req
                                   'out-data)
                             (list (ref* 'a-req)
                                   (ref* 'b-req)
                                   (not* (ref* 'out-ack))
                                   (and*
                                    (not*
                                     (and* (ref* 'a-data)
                                           (ref* 'b-data)))
                                    (or* (ref* 'a-data)
                                         (ref* 'b-data)))))))))
;; For Arduino
;;(prog-synth parity-prog)

;; For Verilog
(synthesize-verilog-program parity-prog 'parity)
