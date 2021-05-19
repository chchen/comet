#lang rosette/safe

(require "config.rkt"
         "paxos.rkt"
         "synth.rkt"
         "arduino/backend.rkt"
         "arduino/mapping.rkt"
         "arduino/semantics.rkt"
         "arduino/syntax.rkt"
         "arduino/synth.rkt"
         "arduino/verify.rkt")

;; Synthesize and verify an acceptor
;; (let* ([prog acceptor]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (time (list (verify-arduino-prog prog impl)
;;               impl)))

;; Synthesize and verify a proposer
;; (let* ([prog proposer]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (time (list (verify-arduino-prog prog impl)
;;               impl)))

;; Interpret a specification to guarded traces
;; (let* ([prog proposer]
;;        [synth-map (unity-prog->synth-map prog)])
;;   (unity-prog->synth-traces prog synth-map))
