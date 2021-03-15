#lang rosette/safe

(require "config.rkt"
         "paxos.rkt"
         "synth.rkt"
         "verilog/backend.rkt"
         "verilog/mapping.rkt"
         "verilog/syntax.rkt"
         "verilog/synth.rkt"
         "verilog/verify.rkt")

;; Before verilog expr inversion fix:
;; cpu time: 12854 real time: 1009093 gc time: 777
;; After expr inversion fix:
;; cpu time: 8795 real time: 448011 gc time: 1245
;; Final
;; cpu time: 5017 real time: 463056 gc time: 242

;; cpu time: 17 real time: 17 gc time: 0
;; cpu time: 368 real time: 1141680 gc time: 44
;; cpu time: 50 real time: 50 gc time: 36
;; cpu time: 296 real time: 741669 gc time: 14
;; (let* ([unity-prog proposer]
;;        [verilog-prog verilog-proposer])
;;   (list
;;    (time (verify-verilog-reset unity-prog verilog-prog))
;;    (time (verify-verilog-clock unity-prog verilog-prog))))

;; cpu time: 6 real time: 6 gc time: 0
;; cpu time: 177 real time: 3887415 gc time: 0
;; cpu time: 4 real time: 5 gc time: 0
;; cpu time: 100 real time: 3668276 gc time: 22
;; (let* ([unity-prog acceptor]
;;        [verilog-prog verilog-acceptor])
;;   (list
;;    (time (verify-verilog-reset unity-prog verilog-prog))
;;    (time (verify-verilog-clock unity-prog verilog-prog))))

;; (time
;;  (let* ([prog mini-test]
;;         [synthesized-module (unity-prog->verilog-module prog 'mini-test)])
;;    synthesized-module))

;; cpu time: 57375 real time: 4974033 gc time: 9814

;; current-bitwidth = 9
;; cpu time: 63782 real time: 1244176 gc time: 13701
;; flatten choose* tree for vectexp??
;; cpu time: 75682 real time: 2357191 gc time: 17017
;; back to normal
;; cpu time: 58104 real time: 1339199 gc time: 11067
;; 32-bit
;; cpu time: 101053 real time: 10041801 gc time: 13496
;; Memoization
;; cpu time: 70291 real time: 3722464 gc time: 11201

(time
 (let* ([prog acceptor]
        [synthesized-module (unity-prog->verilog-module prog 'acceptor)])
   synthesized-module))

;; (time
;;  (let* ([prog proposer]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->synth-traces prog synth-map)))

;; (time
;;  (let* ([prog mini-test]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->verilog-module prog 'mini)))

;; (output-smt "/Users/cchen/Desktop/smt")
;; (time
;;  (let* ([prog mini-test]
;;         [synthesized-module (unity-prog->verilog-module prog 'mini)])
;;    synthesized-module))

;; cpu time: 965423 real time: 7357224 gc time: 587507
;; Fixed bitwidth
;; cpu time: 1920631 real time: 6468498 gc time: 1419084
;; (time
;;  (let* ([prog proposer]
;;         [synthesized-module (unity-prog->verilog-module prog 'proposer)])
;;    synthesized-module))

;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)]
;;         [verifier-results (verify-verilog-module prog synthesized-module)])
;;    (if (verify-ok? verifier-results)
;;        (print-verilog-module synthesized-module)
;;        verifier-results)))
