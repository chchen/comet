#lang rosette/safe

(require "paxos.rkt"
         "verilog/backend.rkt"
         "verilog/synth.rkt"
         "verilog/verify.rkt")

;; cpu time: 136110 real time: 5163055 gc time: 63264
(time
 (let* ([prog mini-test]
        [synthesized-module (unity-prog->verilog-module prog 'mini-test)])
   synthesized-module))

;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)]
;;         [verifier-results (verify-verilog-module prog synthesized-module)])
;;    (if (verify-ok? verifier-results)
;;        (print-verilog-module synthesized-module)
;;        verifier-results)))
