#lang rosette/safe

(require "serial.rkt"
         "arduino/backend.rkt"
         "arduino/synth.rkt"
         "arduino/verify.rkt")

;; (time
;;  (let* ([prog recv-buf-test]
;;         [sketch recv-buf-sketch]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [verify-model (verify-loop prog sketch synth-map)])
;;    verify-model))

;; (print-arduino-program
;;  (unity-prog->arduino-prog sender))

(print-arduino-program
 (unity-prog->arduino-prog receiver))

;; (verify-arduino-prog channel-recv-buf-test
;;                      channel-recv-buf-impl)

;; (time
;;  (let* ([prog channel-recv-buf-test]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [arduino-st->unity-st (synth-map-arduino-state->unity-state synth-map)]
;;         [arduino-start-st (synth-map-arduino-symbolic-state synth-map)]
;;         [unity-start-st (arduino-st->unity-st arduino-start-st)]
;;         [assign-traces (synth-traces-assign (unity-prog->synth-traces prog synth-map))])
;;    assign-traces))
