#lang rosette/safe

(require "config.rkt"
         "unity/syntax.rkt")

(define round-robin-sender1
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           )))))

(define round-robin-sender2
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 2)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 2))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           )))))

(define round-robin-sender3
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 3)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 3))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           (:=* (list 'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out3)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 3)))))))
           )))))

(define round-robin-sender4
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 4)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 4))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           (:=* (list 'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out3)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 3)))))))
           (:=* (list 'out4
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out4)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 4)))))))
           )))))

(define round-robin-sender5
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'out5 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 5)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 5))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           (:=* (list 'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out3)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 3)))))))
           (:=* (list 'out4
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out4)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 4)))))))
           (:=* (list 'out5
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out5)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 5)))))))
           )))))

(define round-robin-sender6
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'out5 'send-channel)
          (cons 'out6 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 6)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 6))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           (:=* (list 'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out3)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 3)))))))
           (:=* (list 'out4
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out4)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 4)))))))
           (:=* (list 'out5
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out5)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 5)))))))
           (:=* (list 'out6
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out6)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 6)))))))
           )))))

(define round-robin-sender7
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'out5 'send-channel)
          (cons 'out6 'send-channel)
          (cons 'out7 'send-channel)
          (cons 'val 'natural)
          (cons 'select 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'select
                'buf)
          (list
           42
           1
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf
                      'select)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val)
                                   (+* 'select 1))
                             (and* (send-buf-empty?* 'buf)
                                   (<* 'select 7)))
                       (cons (list (nat->send-buf* vect-len 'val)
                                   1)
                             (and* (send-buf-empty?* 'buf)
                                   (=* 'select 7))))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 1)))))))
           (:=* (list 'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out2)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 2)))))))
           (:=* (list 'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out3)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 3)))))))
           (:=* (list 'out4
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out4)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 4)))))))
           (:=* (list 'out5
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out5)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 5)))))))
           (:=* (list 'out6
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out6)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 6)))))))
           (:=* (list 'out7
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out7)
                                   (and* (not* (send-buf-empty?* 'buf))
                                         (=* 'select 7)))))))
           )))))



(provide round-robin-sender1
         round-robin-sender2
         round-robin-sender3
         round-robin-sender4
         round-robin-sender5
         round-robin-sender6
         round-robin-sender7)
