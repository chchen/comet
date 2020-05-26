#lang rosette

(require "arduino/buffer.rkt"
         "arduino/channel.rkt"
         "arduino/inversion.rkt"
         "arduino/semantics.rkt"
         "arduino/symbolic.rkt"
         "arduino/synth.rkt"
         "unity/syntax.rkt"
         (prefix-in arduino: "arduino/environment.rkt")
         (prefix-in arduino: "arduino/syntax.rkt")
         (prefix-in unity: "unity/environment.rkt")
         (prefix-in unity: "unity/semantics.rkt"))

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

(define channel-sketch
  (list
   (arduino:if*
    (arduino:and* (arduino:not* 'in-read)
                  (arduino:and* (arduino:eq* (arduino:read* 'd4)
                                             (arduino:read* 'd3))
                                (arduino:not* (arduino:eq* (arduino:read* 'd0)
                                                           (arduino:read* 'd1)))))
    (list
     (arduino::=* 'in-read 'true)
     (arduino:write* 'd5 (arduino:read* 'd2))
     (arduino:write* 'd3 (arduino:not* (arduino:read* 'd4))))
    (list
     (arduino:if*
      (arduino:and* 'in-read
                    (arduino:not* (arduino:eq* (arduino:read* 'd0) (arduino:read* 'd1))))
      (list
       (arduino::=* 'in-read 'false)
       (arduino:write* 'd1 (arduino:read* 'd0)))
      '())))))

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

(define recv-buf-sketch
  (list
   (arduino:if*
    (arduino:not* (arduino:lt* (bv #x07 8) 'r_rcvd))
    (list
     (arduino::=*
      'r_vals
      (arduino:bwor*
       (arduino:bwand*
        'r_vals
        (arduino:bwnot*
         (arduino:shl*
          (bv 1 8)
          'r_rcvd)))
       (arduino:shl*
        (arduino:and*
         'x
         'x)
        'r_rcvd)))
     (arduino::=* 'r_rcvd (arduino:add* 'r_rcvd (bv 1 8))))
    '())))

(define send-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 's 'send-buf)))
   (initially*
    (list
     (:=* (list 'x
                's)
          (list #f
                (nat->send-buf* 8 16)))))
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
    (:=* (list 'x
               'r
               's)
         (list #f
               (empty-recv-buf* 8)
               (nat->send-buf* 8 42))))
   '()))

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
    (:=* (list 'b 'n 'r 's 'o)
         (list #f
               42
               (empty-recv-buf* 8)
               (nat->send-buf* 8 42)
               'empty)))
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
    (:=* (list 'out
               'cycle
               'val)
         (list 'empty
               #t
               42)))
   (assign*
    (list (:=* (list 'out
                     'buf
                     'cycle)
               (case*
                (list (cons (list (message* (send-buf-get* 'buf))
                                  (send-buf-next* 'buf)
                                  #f)
                            (and* (empty?* 'out)
                                  (not* (send-buf-empty?* 'buf))))
                      (cons (list 'out
                                  (nat->send-buf* 8 'val)
                                  #f)
                            (and* (empty?* 'out)
                                  (or* (send-buf-empty?* 'buf)
                                       'cycle))))))))))

(define receiver
  (unity*
   (declare*
    (list (cons 'in 'recv-channel)
          (cons 'buf 'recv-buf)
          (cons 'rcvd 'boolean)
          (cons 'val 'natural)))
   (initially*
    (:=* (list 'buf
               'rcvd)
         (list (empty-recv-buf* 8)
               #f)))
   (assign*
    (list (:=* (list 'in
                     'buf
                     'rcvd
                     'val)
               (case*
                (list (cons (list 'empty
                                  (recv-buf-put* 'buf (value* 'in))
                                  'rcvd
                                  'val)
                            (and* (full?* 'in)
                                  (not* (recv-buf-full?* 'buf))))
                      (cons (list 'in
                                  (empty-recv-buf* 8)
                                  #t
                                  (recv-buf->nat* 'buf))
                            (recv-buf-full?* 'buf)))))))))


;; (time
;;  (let* ([prog recv-buf-test]
;;         [sketch recv-buf-sketch]
;;         [synth-map (unity-prog->synth-map prog)]
;;         [verify-model (verify-loop prog sketch synth-map)])
;;    verify-model))

(time
 (let* ([prog recv-buf-test]
        [synth-map (unity-prog->synth-map prog)]
        [synth-tr (unity-prog->synth-traces prog synth-map)]
        [buffer-preds (buffer-predicates prog synth-map)]
        [channel-preds (channel-predicates prog synth-map)]
        [preds (append buffer-preds
                       channel-preds)]
        [initially-guarded-traces (synth-traces-initially synth-tr)]
        [assign-guarded-traces (synth-traces-assign synth-tr)]
        [setup-stmts (try-synth-trace initially-guarded-traces
                                      synth-map
                                      #f
                                      '())]
        [guard-exps (map
                     (lambda (guarded-tr)
                       (try-synth-guard guarded-tr
                                        synth-map
                                        preds))
                     assign-guarded-traces)]
        [assign-stmts (map
                       (lambda (guarded-tr)
                         (try-synth-trace guarded-tr
                                          synth-map
                                          #t
                                          buffer-preds))
                       assign-guarded-traces)])
 (list setup-stmts
       guard-exps
       assign-stmts)))
;;    ;; (try-synth-loop prog
;;    ;;                 synth-map
;;    ;;                 guard-exps
;;    ;;                 assign-stmts)))
