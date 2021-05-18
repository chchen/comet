#lang rosette/safe

(require "config.rkt"
         "serial.rkt"
         "synth.rkt"
         "bool-bitvec/synth.rkt"
         "verilog/backend.rkt"
         "verilog/synth.rkt"
         "verilog/mapping.rkt"
         "verilog/verify.rkt"
         rosette/lib/value-browser)

;; (time
;;  (let* ([prog channel-test]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [buf-preds (buffer-predicates prog synth-map)]
;;         [chan-preds (channel-predicates prog synth-map)]
;;         [preds (append buf-preds chan-preds)]
;;         [synth-traces (unity-prog->synth-traces prog synth-map)]
;;         [initially-trace (synth-traces-initially synth-traces)]
;;         [assign-traces (synth-traces-assign synth-traces)])
;;    (map (lambda (g-t)
;;           (unity-trace->target-trace synth-map
;;                                      (guarded-trace-guard g-t)
;;                                      (guarded-trace-trace g-t)))
;;         assign-traces)))

;; (let* ([prog receiver]
;;        [synthesized-module (unity-prog->verilog-module prog 'synth-test)]
;;        [verifier-results (verify-verilog-module prog synthesized-module)])
;;   (if (verify-ok? verifier-results)
;;       (print-verilog-module synthesized-module)
;;       verifier-results))

(let* ([prog channel-fifo]
       [impl (time (unity-prog->verilog-module prog 'test))])
  (time (verify-verilog-module prog impl)))

;; (time
;;  (let* ([prog channel-test])
;;    (unity-prog->verilog-module prog 'test)))

;; (time
;;  (let* ([prog channel-test]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [buf-preds (buffer-predicates prog synth-map)]
;;         [chan-preds (channel-predicates prog synth-map)]
;;         [preds (append buf-preds chan-preds)]
;;         [synth-traces (unity-prog->synth-traces prog synth-map)]
;;         [initially-trace (synth-traces-initially synth-traces)]
;;         [assign-traces (synth-traces-assign synth-traces)])
;;    (list
;;     (unity-guarded-trace->guarded-stmts synth-map initially-trace '())
;;     (map (lambda (g-t)
;;            (unity-guarded-trace->guarded-stmts synth-map g-t preds))
;;          assign-traces))))

;; (time
;;  (let* ([prog channel-test]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [buf-preds (buffer-predicates prog synth-map)]
;;         [chan-preds (channel-predicates prog synth-map)])
;;    (list buf-preds
;;          chan-preds)))

;; (time
;;  (unity-prog->arduino-prog send-buf-test))

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

;; (time
;;  (let* ([prog channel-fifo]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->synth-traces prog synth-map)))
