#lang rosette/safe

(require "unity/syntax.rkt"
         (prefix-in arduino: "arduino/syntax.rkt"))

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

(define channel-recv-buf-impl
  (arduino:arduino*
   (arduino:setup*
    (list
     (arduino:pin-mode* 'd2 'INPUT)
     (arduino:pin-mode* 'd1 'OUTPUT)
     (arduino:pin-mode* 'd0 'INPUT)
     (arduino:byte* 'r_vals)
     (arduino:byte* 'r_rcvd)
     (arduino::=* 'r_rcvd (bv #x00 8))
     (arduino::=* 'r_vals (bv #x00 8))))
   (arduino:loop*
    (list
     (arduino:if*
      (arduino:lt*
       (arduino:lt* (arduino:bwor* 'r_rcvd (bv #x08 8))
                    (arduino:add* 'r_rcvd 'r_rcvd))
       (arduino:bwxor* (arduino:read* 'd0)
                       (arduino:read* 'd1)))
      (list (arduino::=* 'r_vals
                         (arduino:bwxor*
                          (arduino:bwor* (arduino:shl* (bv #x01 8)
                                                       'r_rcvd)
                                         'r_vals)
                          (arduino:shl* (arduino:lt* (arduino:read* 'd2)
                                                     (bv #x01 8))
                                        (arduino:shr* 'r_rcvd
                                                      (arduino:read* 'd2)))))
            (arduino::=* 'r_rcvd
                         (arduino:add* 'r_rcvd (bv #x01 8))))
      '())))))

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

(define send-buf-impl
  (arduino:arduino*
   (arduino:setup*
    (list
     (arduino:byte* 'x)
     (arduino:byte* 's_vals)
     (arduino:byte* 's_sent)
     (arduino::=* 's_vals (bv #x10 8))
     (arduino::=* 'x (bv #x00 8))
     (arduino::=* 's_sent (bv #x00 8))))
   (arduino:loop*
    (list
     (arduino:if*
      (arduino:lt* (arduino:lt* (bv #x87 8) (arduino:bwxor* (bv #x87 8) 's_sent)) (bv #x01 8))
      (list
       (arduino::=* 's_vals
                    's_vals)
       (arduino::=* 'x
                    (arduino:bwand* (arduino:shr* 's_vals
                                                  's_sent)
                                    (arduino:or* (bv #x04 8)
                                                 's_sent)))
       (arduino::=* 's_sent
                    (arduino:add* 's_sent
                                  (bv #x01 8))))
      '())))))

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
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'out
                'val
                'buf)
          (list 'empty
                42
                (empty-send-buf* 8)))))
   (assign*
    (list
     (list (:=* (list 'out
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out)
                                   (not* (send-buf-empty?* 'buf))))
                       (cons (list 'out
                                   (nat->send-buf* 8 'val))
                             (and* (empty?* 'out)
                                   (send-buf-empty?* 'buf)))))))))))

(define sender-test
  (unity*
   (declare*
    (list (cons 'out 'send-channel)
          (cons 'buf 'boolean)
          (cons 'cycle 'boolean)))
   (initially*
    (list
     (:=* (list 'out
                'buf
                'cycle)
          (list 'empty
                #t
                #t))))
   (assign*
    (list
     (list
      (:=* (list 'out
                 'buf
                 'cycle)
           (case*
            (list (cons (list (message* 'buf)
                              'buf
                              #f)
                        (and* (empty?* 'out)
                              (and* 'buf
                                    'cycle))))))
      (:=* (list 'cycle)
           (case*
            (list (cons (list #t)
                        (and* (empty?* 'out)
                              (and* 'buf
                                    (not* 'cycle))))))))))))

(define guard-test
  (unity*
   (declare*
    (list (cons 'a 'boolean)
          (cons 'b 'boolean)
          (cons 'c 'boolean)
          (cons 'out 'boolean)))
   (initially*
    (list
     (:=* (list 'out)
          (list #f))))
   (assign*
    (list
     (list
      (:=* (list 'out)
           (case*
            (list (cons (list #t)
                        (and* 'a
                              (and* 'b
                                    'c))))))
      (:=* (list 'out)
           (case*
            (list (cons (list #f)
                        (and* 'a
                              (and* 'b
                                    (not* 'c))))))))))))

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

(provide channel-test
         send-buf-test
         recv-buf-test
         sender
         sender-test
         guard-test
         receiver)
