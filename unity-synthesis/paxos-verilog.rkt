#lang rosette/safe

(require "config.rkt"
         "paxos.rkt"
         "synth.rkt"
         "verilog/backend.rkt"
         "verilog/mapping.rkt"
         "verilog/syntax.rkt"
         "verilog/synth.rkt"
         "verilog/verify.rkt")

;; Synthesize and verify an acceptor
;; (let* ([prog acceptor]
;;        [impl (time (unity-prog->verilog-module prog 'acceptor))])
;;   (time (list (verify-verilog-module prog impl)
;;               impl)))

;; Synthesize and verify a proposer
;; (let* ([prog proposer]
;;        [impl (time (unity-prog->verilog-module prog 'proposer))])
;;   (time (list (verify-verilog-module prog impl)
;;               impl)))

;; Interpret a specification to guarded traces
;; (let* ([prog proposer]
;;        [synth-map (unity-prog->synth-map prog)])
;;   (unity-prog->synth-traces prog synth-map))
