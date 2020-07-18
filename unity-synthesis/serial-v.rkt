#lang rosette/safe

(require "synth.rkt"
         "bool-bitvec/synth.rkt"
         "verilog/synth.rkt"
         "verilog/buffer.rkt"
         "verilog/channel.rkt"
         "verilog/mapping.rkt"
         "verilog/verify.rkt"
         "unity/syntax.rkt")

(define boolean-test
  (unity*
   (declare*
    (list (cons 'lead 'boolean)
          (cons 'follow 'boolean)))
   (initially*
    (list
     (:=* (list 'lead
                'follow)
          (list #t
                #f))))
   (assign*
    (list
     (list
      (:=* (list 'follow)
           (case* (list (cons (list 'lead)
                              (not* (eq* 'lead
                                         'follow))))))
      (:=* (list 'lead)
           (case* (list (cons (list (not* 'lead))
                              (eq* 'lead
                                   'follow))))))))))

(define channel-test
  (unity*
   (declare*
    (list (cons 'in-read 'boolean)
          (cons 'in 'recv-channel)
          (cons 'out 'send-channel)))
   (initially*
    (list
     (:=* (list 'in-read)
          (list #f))))
   (assign*
    (list
     ;; Each parallel assignment is independent. A parallel composition of
     ;; simple assignments is identical to a single multi-assignment.
     (list
      ;; parallel assignment A. A case assignment is deterministic. That is,
      ;; either the cases are mutually exclusive, or if two cases are enabled,
      ;; their assignments are identical in effect. Let's choose to make them
      ;; mutually exclusive, that is, if A contains guards g1 and g2, then (and
      ;; g1 g2) == unsat
      (:=* (list 'in-read
                 'out)
           (case* (list (cons (list #t
                                    (message* (value* 'in)))
                              (and* (not* 'in-read)
                                    (and* (empty?* 'out)
                                          (full?* 'in)))))))
      ;; parallel assignment B
      (:=* (list 'in-read
                 'in)
           (case* (list (cons (list #f
                                    'empty)
                              (and* 'in-read
                                    (full?* 'in)))))))))))

(define recv-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 'r 'recv-buf)))
   (initially*
    (list
     (:=* (list 'x
                'r)
          (list #f
                (empty-recv-buf* 8)))))
   (assign*
    (list
     (list
      (:=* (list 'r)
           (case*
            (list (cons (list (recv-buf-put* 'r 'x))
                        (not* (recv-buf-full?* 'r)))))))))))

(define channel-recv-buf-test
  (unity*
   (declare*
    (list (cons 'in 'recv-channel)
          (cons 'r 'recv-buf)))
   (initially*
    (list
     (:=* (list 'r)
          (list (empty-recv-buf* 8)))))
   (assign*
    (list
     (list
      (:=* (list 'r)
           (case*
            (list (cons (list (recv-buf-put* 'r (value* 'in)))
                        (and* (full?* 'in)
                              (not* (recv-buf-full?* 'r))))))))))))

(define send-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 's 'send-buf)
          (cons 'v 'natural)))
   (initially*
    (list
     (:=* (list 'x
                's
                'v)
          (list #f
                (nat->send-buf* 8 16)
                42))))
   (assign*
    (list
     (list
      (:=* (list 's
                 'x)
           (case*
            (list (cons (list (send-buf-next* 's)
                              (send-buf-get* 's))
                        (not* (send-buf-empty?* 's)))))))))))

(define buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 'r 'recv-buf)
          (cons 's 'send-buf)))
   (initially*
    (list
     (:=* (list 'x
                'r
                's)
          (list #f
                (empty-recv-buf* 8)
                (nat->send-buf* 8 42)))))
   (assign* '())))

(define type-test
  (unity*
   (declare*
    (list (cons 'b 'boolean)
          (cons 'n 'natural)
          (cons 'r 'recv-buf)
          (cons 's 'send-buf)
          (cons 'i 'recv-channel)
          (cons 'o 'send-channel)))
   (initially*
    (list
     (:=* (list 'b 'n 'r 's 'o)
          (list #f
                42
                (empty-recv-buf* 8)
                (nat->send-buf* 8 42)
                (message* #t)))))
   (assign*
    '())))

(define sender
  (unity*
   (declare*
    (list (cons 'out 'send-channel)
          (cons 'buf 'send-buf)
          (cons 'val 'natural)
          (cons 'cycle 'boolean)))
   (initially*
    (list
     (:=* (list 'out
                'cycle
                'val)
          (list 'empty
                #t
                42))))
   (assign*
    (list
     (list (:=* (list 'out
                      'buf
                      'cycle)
                (case*
                 (list
                  (cons (list (message* (send-buf-get* 'buf))
                              (send-buf-next* 'buf)
                              #f)
                        (and* (empty?* 'out)
                              (not* (send-buf-empty?* 'buf))))
                  (cons (list 'out
                              (nat->send-buf* 8 'val)
                              #f)
                        (and* (empty?* 'out)
                              (or* (send-buf-empty?* 'buf)
                                   'cycle)))))))))))

(define receiver
  (unity*
   (declare*
    (list (cons 'in 'recv-channel)
          (cons 'buf 'recv-buf)
          (cons 'rcvd 'boolean)
          (cons 'val 'natural)))
   (initially*
    (list
     (:=* (list 'buf
                'rcvd)
          (list (empty-recv-buf* 8)
                #f))))
   (assign*
    (list
     (list (:=* (list 'in
                      'buf
                      'rcvd
                      'val)
                (case*
                 (list
                  (cons (list 'empty
                              (recv-buf-put* 'buf (value* 'in))
                              'rcvd
                              'val)
                        (and* (full?* 'in)
                              (not* (recv-buf-full?* 'buf))))
                  (cons (list 'in
                              (empty-recv-buf* 8)
                              #t
                              (recv-buf->nat* 'buf))
                        (recv-buf-full?* 'buf))))))))))


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

(time
 (let* ([prog channel-test]
        [synthesized-module (unity-prog->verilog-module prog 'synth-test)]
        [verifier-results (verify-verilog-module prog synthesized-module)])
   (list synthesized-module
         verifier-results)))

;; (time
;;  (let* ([prog channel-test]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (unity-prog->always-block synth-map prog)))

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
