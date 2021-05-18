#lang rosette/safe

(require "config.rkt"
         "unity/syntax.rkt")

(define batch-sender1
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (not* (send-buf-empty?* 'buf))))))))))))

(define batch-sender2
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (not* (send-buf-empty?* 'buf)))))))))))))

(define batch-sender3
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'out3
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (and* (empty?* 'out3)
                                               (not* (send-buf-empty?* 'buf))))))))))))))

(define batch-sender4
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'out3
                      'out4
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (and* (empty?* 'out3)
                                               (and* (empty?* 'out4)
                                                     (not* (send-buf-empty?* 'buf)))))))))))))))

(define batch-sender5
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'out5 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'out3
                      'out4
                      'out5
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (and* (empty?* 'out3)
                                               (and* (empty?* 'out4)
                                                     (and* (empty?* 'out5)
                                                           (not* (send-buf-empty?* 'buf))))))))))))))))

(define batch-sender6
  (unity*
   (declare*
    (list (cons 'out1 'send-channel)
          (cons 'out2 'send-channel)
          (cons 'out3 'send-channel)
          (cons 'out4 'send-channel)
          (cons 'out5 'send-channel)
          (cons 'out6 'send-channel)
          (cons 'val 'natural)
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'out3
                      'out4
                      'out5
                      'out6
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (and* (empty?* 'out3)
                                               (and* (empty?* 'out4)
                                                     (and* (empty?* 'out5)
                                                           (and* (empty?* 'out6)
                                                                 (not* (send-buf-empty?* 'buf)))))))))))))))))

(define batch-sender7
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
          (cons 'buf 'send-buf)))
   (initially*
    (list
     (:=* (list 'val
                'buf)
          (list
           42
           (empty-send-buf* vect-len)))))
   (assign*
    (list
     (list (:=* (list 'buf)
                (case*
                 (list (cons (list (nat->send-buf* vect-len 'val))
                                   (send-buf-empty?* 'buf)))))
           (:=* (list 'out1
                      'out2
                      'out3
                      'out4
                      'out5
                      'out6
                      'out7
                      'buf)
                (case*
                 (list (cons (list (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (message* (send-buf-get* 'buf))
                                   (send-buf-next* 'buf))
                             (and* (empty?* 'out1)
                                   (and* (empty?* 'out2)
                                         (and* (empty?* 'out3)
                                               (and* (empty?* 'out4)
                                                     (and* (empty?* 'out5)
                                                           (and* (empty?* 'out6)
                                                                 (and* (empty?* 'out7)
                                                                       (not* (send-buf-empty?* 'buf))))))))))))))))))

(provide batch-sender1
         batch-sender2
         batch-sender3
         batch-sender4
         batch-sender5
         batch-sender6
         batch-sender7)
