#lang rosette/safe

(require "config.rkt"
         "serial.rkt"
         "synth.rkt"
         "arduino/backend.rkt"
         "arduino/synth.rkt"
         "arduino/mapping.rkt"
         "arduino/verify.rkt")

;; (time
;;  (let* ([prog recv-buf-test]
;;         [sketch recv-buf-sketch]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [verify-model (verify-loop prog sketch synth-map)])
;;    verify-model))

;; (time
;; (print-arduino-program
;;  (unity-prog->arduino-prog channel-fifo)))

;; (time (print-arduino-program
;;        (unity-prog->arduino-prog channel-test)))

;; (unity-prog->arduino-prog channel-test)

(unity-prog->arduino-prog send-buf-test)

;; (verify-arduino-prog channel-recv-buf-test
;;                      channel-recv-buf-impl)

;; (let* ([prog receiver]
;;        [synth-map (unity-prog->synth-map prog)]
;;        [arduino-st->unity-st (synth-map-target-state->unity-state synth-map)]
;;        [arduino-start-st (synth-map-target-state synth-map)]
;;        [unity-start-st (arduino-st->unity-st arduino-start-st)]
;;        [assign-traces (synth-traces-assign (unity-prog->synth-traces prog synth-map))])
;;   assign-traces)

;; (time
;;  (let* ([prog sender]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->assign-state prog synth-map)))

;; (time
;;  (let* ([prog channel-test]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->synth-traces prog synth-map)))
