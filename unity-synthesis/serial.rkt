#lang rosette

(require "unity/syntax.rkt"
         "arduino/synth.rkt"
         "arduino/channel.rkt"
         "arduino/buffer.rkt")

(define channel-test
  (unity*
   (declare*
    (list (cons 'o 'send-channel)
          (cons 'i 'recv-channel)))
   (initially*
    (:=* (list 'o)
         (list 'empty)))
   (assign*
    (list (:=* (list 'o)
               (case*
                (list (cons (list (message* #t))
                            (empty?* 'o)))))))))

(define recv-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 'r 'recv-buf)))
   (initially*
    (:=* (list 'x
               'r)
         (list #f
               (empty-recv-buf* 8))))
   '()))

(define send-buf-test
  (unity*
   (declare*
    (list (cons 'x 'boolean)
          (cons 's 'send-buf)))
   (initially*
    (:=* (list 'x
               's)
         (list #f
               (nat->send-buf* 8 1))))
   (assign*
    (:=* (list 'x)
         (list (send-buf-get* 's))))))

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

