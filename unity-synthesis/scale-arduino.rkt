#lang rosette/safe

(require "arduino/backend.rkt"
         "arduino/mapping.rkt"
         "arduino/synth.rkt"
         "arduino/verify.rkt"
         "config.rkt"
         "round-robin-sender.rkt"
         "synth.rkt"
         "batch-sender.rkt")

(define (run-test prog)
  (let ([impl (time (unity-prog->arduino-prog prog))])
    (time (verify-arduino-prog prog impl))))

;; Run all tests
(map run-test
     (list round-robin-sender1
           round-robin-sender2
           round-robin-sender3
           round-robin-sender4
           round-robin-sender5
           round-robin-sender6
           round-robin-sender7
           batch-sender2
           batch-sender3
           batch-sender4
           batch-sender5
           batch-sender6
           batch-sender7))

;; Extract guarded traces for fun
;; (let* ([prog round-robin-sender7]
;;        [synth-map (unity-prog->synth-map prog)])
;;   (unity-prog->synth-traces prog synth-map))
