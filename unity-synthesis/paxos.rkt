#lang rosette/safe

(require "unity/syntax.rkt")

;; Model a Paxos proposer
;; A proposer sends phase 1a and 2a and receives phase 1b and 2b messages
;; Internal vars:
;; Ballot
;; Value
;; Phase
;; Sent#
;; Rcvd#
;; Send/Recv Buffers for each Acceptor
;; Send/Recv Channels for each Acceptor

(define proposer
  (unity*
   (declare*
    (list (cons 'ballot 'natural)
          (cons 'value 'natural)
          (cons 'phase 'natural)
          (cons 'a_mbal 'natural)
          (cons 'b_mbal 'natural)
          (cons 'c_mbal 'natural)
          (cons 'a_mval 'natural)
          (cons 'b_mval 'natural)
          (cons 'c_mval 'natural)
          (cons 'out_a 'send-channel)
          (cons 'out_b 'send-channel)
          (cons 'out_c 'send-channel)
          (cons 'in_a 'recv-channel)
          (cons 'in_b 'recv-channel)
          (cons 'in_c 'recv-channel)
          (cons 'out_a_bal 'send-buf)
          (cons 'out_b_bal 'send-buf)
          (cons 'out_c_bal 'send-buf)
          (cons 'out_a_val 'send-buf)
          (cons 'out_b_val 'send-buf)
          (cons 'out_c_val 'send-buf)
          (cons 'in_a_bal 'recv-buf)
          (cons 'in_b_bal 'recv-buf)
          (cons 'in_c_bal 'recv-buf)
          (cons 'in_a_val 'recv-buf)
          (cons 'in_b_val 'recv-buf)
          (cons 'in_c_val 'recv-buf)))
   (initially*
    (list
     (:=* (list 'ballot
                'value
                'phase
                'out_a
                'out_b
                'out_c)
          (list 1
                32
                1
                'empty
                'empty
                'empty))))
   (assign*
    (list
     (list
      ;; Phase 0: Accepting state
      ;; Phase 255: Failure state
      ;; 01 Failure mode: max ballot value
      (:=* (list 'phase)
           (case*
            (list (cons (list 255)
                        (=* 'ballot 255)))))
      ;; 02 Phase 1->2: load buffers for sending prepare messages
      (:=* (list 'out_a_bal
                 'out_b_bal
                 'out_c_bal
                 'phase)
           (case*
            (list (cons (list (nat->send-buf* 8 'ballot)
                              (nat->send-buf* 8 'ballot)
                              (nat->send-buf* 8 'ballot)
                              2)
                        (=* 'phase 1)))))
      ;; 03 Phase 2: send promise message to acceptors
      (:=* (list 'out_a
                 'out_a_bal)
           (case*
            (list
             (cons (list (message* (send-buf-get* 'out_a_bal))
                         (send-buf-next* 'out_a_bal))
                   (and* (empty?* 'out_a)
                         (and* (not* (send-buf-empty?* 'out_a_bal))
                               (=* 'phase 2)))))))
      ;; 04
      (:=* (list 'out_b
                 'out_b_bal)
           (case*
            (list
             (cons (list (message* (send-buf-get* 'out_b_bal))
                         (send-buf-next* 'out_b_bal))
                   (and* (empty?* 'out_b)
                         (and* (not* (send-buf-empty?* 'out_b_bal))
                               (=* 'phase 2)))))))
      ;; 05
      (:=* (list 'out_c
                 'out_c_bal)
           (case*
            (list
             (cons (list (message* (send-buf-get* 'out_c_bal))
                         (send-buf-next* 'out_c_bal))
                   (and* (empty?* 'out_c)
                         (and* (not* (send-buf-empty?* 'out_c_bal))
                               (=* 'phase 2)))))))
      ;; 06 Phase 2->3: prepare receive buffers
      (:=* (list 'in_a_bal
                 'in_b_bal
                 'in_c_bal
                 'in_a_val
                 'in_b_val
                 'in_c_val
                 'phase)
           (case*
            (list (cons (list (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              3)
                        (and* (send-buf-empty?* 'out_a_bal)
                              (and* (send-buf-empty?* 'out_b_bal)
                                    (and* (send-buf-empty?* 'out_c_bal)
                                          (=* 'phase 2))))))))
      ;; Phase 3: receive promise replies from acceptors
      (:=* (list 'in_a
                 'in_a_bal
                 'in_a_val)
           (case*
            (list
             ;; 07
             (cons (list 'empty
                         (recv-buf-put* 'in_a_bal (value* 'in_a))
                         'in_a_val)
                   (and* (full?* 'in_a)
                         (and* (not* (recv-buf-full?* 'in_a_bal))
                               (=* 'phase 3))))
             ;; 08
             (cons (list 'empty
                         'in_a_bal
                         (recv-buf-put* 'in_a_val (value* 'in_a)))
                   (and* (full?* 'in_a)
                         (and* (recv-buf-full?* 'in_a_bal)
                               (and* (not* (recv-buf-full?* 'in_a_val))
                                     (=* 'phase 3))))))))
      (:=* (list 'in_b
                 'in_b_bal
                 'in_b_val)
           (case*
            (list
             ;; 09
             (cons (list 'empty
                         (recv-buf-put* 'in_b_bal (value* 'in_b))
                         'in_b_val)
                   (and* (full?* 'in_b)
                         (and* (not* (recv-buf-full?* 'in_b_bal))
                               (=* 'phase 3))))
             ;; 10
             (cons (list 'empty
                         'in_b_bal
                         (recv-buf-put* 'in_b_val (value* 'in_b)))
                   (and* (full?* 'in_b)
                         (and* (recv-buf-full?* 'in_b_bal)
                               (and* (not* (recv-buf-full?* 'in_b_val))
                                     (=* 'phase 3))))))))
      (:=* (list 'in_c
                 'in_c_bal
                 'in_c_val)
           (case*
            (list
             ;; 11
             (cons (list 'empty
                         (recv-buf-put* 'in_c_bal (value* 'in_c))
                         'in_c_val)
                   (and* (full?* 'in_c)
                         (and* (not* (recv-buf-full?* 'in_c_bal))
                               (=* 'phase 3))))
             ;; 12
             (cons (list 'empty
                         'in_c_bal
                         (recv-buf-put* 'in_c_val (value* 'in_c)))
                   (and* (full?* 'in_c)
                         (and* (recv-buf-full?* 'in_c_bal)
                               (and* (not* (recv-buf-full?* 'in_c_val))
                                     (=* 'phase 3))))))))
      ;; 13 Phase 3->4
      (:=* (list 'a_mbal
                 'b_mbal
                 'c_mbal
                 'a_mval
                 'b_mval
                 'c_mval
                 'phase)
           (case*
            (list (cons (list (recv-buf->nat* 'in_a_bal)
                              (recv-buf->nat* 'in_b_bal)
                              (recv-buf->nat* 'in_c_bal)
                              (recv-buf->nat* 'in_a_val)
                              (recv-buf->nat* 'in_b_val)
                              (recv-buf->nat* 'in_c_val)
                              4)
                        (and* (recv-buf-full?* 'in_a_val)
                              (and* (recv-buf-full?* 'in_b_val)
                                    (and* (recv-buf-full?* 'in_c_val)
                                          (=* 'phase 3))))))))
      ;; Phase 4->5: select value
      (:=* (list 'value
                 'phase)
           (case*
            (list
             ;; 14
             (cons (list 'value
                         5)
                   (and* (=* 0 'a_mbal)
                         (and* (=* 0 'b_mbal)
                               (and* (=* 0 'c_mbal)
                                     (=* 'phase 4)))))
             ;; 15
             (cons (list 'a_mval
                         5)
                   (and* (or* (=* 'b_mbal 'a_mbal)
                              (<* 'b_mbal 'a_mbal))
                         (and* (or* (=* 'c_mbal 'a_mbal)
                                    (<* 'c_mbal 'a_mbal))
                               (=* 'phase 4))))
             ;; 16
             (cons (list 'b_mval
                         5)
                   (and* (or* (=* 'a_mbal 'b_mbal)
                              (<* 'a_mbal 'b_mbal))
                         (and* (or* (=* 'c_mbal 'b_mbal)
                                    (<* 'c_mbal 'b_mbal))
                               (=* 'phase 4))))
             ;; 17
             (cons (list 'c_mval
                         5)
                   (and* (or* (=* 'a_mbal 'c_mbal)
                              (<* 'a_mbal 'c_mbal))
                         (and* (or* (=* 'b_mbal 'c_mbal)
                                    (<* 'b_mbal 'c_mbal))
                               (=* 'phase 4)))))))
      ;; 18 Phase 5->6: load buffers for sending vote messages
      (:=* (list 'out_a_bal
                 'out_b_bal
                 'out_c_bal
                 'out_a_val
                 'out_b_val
                 'out_c_val
                 'phase)
           (case*
            (list (cons (list (nat->send-buf* 8 'ballot)
                              (nat->send-buf* 8 'ballot)
                              (nat->send-buf* 8 'ballot)
                              (nat->send-buf* 8 'value)
                              (nat->send-buf* 8 'value)
                              (nat->send-buf* 8 'value)
                              6)
                        (=* 'phase 5)))))
      ;; Phase 6: send vote message to acceptors
      (:=* (list 'out_a
                 'out_a_bal
                 'out_a_val)
           (case*
            (list
             ;; 19
             (cons (list (message* (send-buf-get* 'out_a_bal))
                         (send-buf-next* 'out_a_bal)
                         'out_a_val)
                   (and* (empty?* 'out_a)
                         (and* (not* (send-buf-empty?* 'out_a_bal))
                               (=* 'phase 6))))
             ;; 20
             (cons (list (message* (send-buf-get* 'out_a_val))
                         'out_a_bal
                         (send-buf-next* 'out_a_val))
                   (and* (empty?* 'out_a)
                         (and* (send-buf-empty?* 'out_a_bal)
                               (and* (not* (send-buf-empty?* 'out_a_val))
                                     (=* 'phase 6))))))))
      (:=* (list 'out_b
                 'out_b_bal
                 'out_b_val)
           (case*
            (list
             ;; 21
             (cons (list (message* (send-buf-get* 'out_b_bal))
                         (send-buf-next* 'out_b_bal)
                         'out_b_val)
                   (and* (empty?* 'out_b)
                         (and* (not* (send-buf-empty?* 'out_b_bal))
                               (=* 'phase 6))))
             ;; 22
             (cons (list (message* (send-buf-get* 'out_b_val))
                         'out_b_bal
                         (send-buf-next* 'out_b_val))
                   (and* (empty?* 'out_b)
                         (and* (send-buf-empty?* 'out_b_bal)
                               (and* (not* (send-buf-empty?* 'out_b_val))
                                     (=* 'phase 6))))))))
      (:=* (list 'out_c
                 'out_c_bal
                 'out_c_val)
           (case*
            (list
             ;; 23
             (cons (list (message* (send-buf-get* 'out_c_bal))
                         (send-buf-next* 'out_c_bal)
                         'out_c_val)
                   (and* (empty?* 'out_c)
                         (and* (not* (send-buf-empty?* 'out_c_bal))
                               (=* 'phase 6))))
             ;; 24
             (cons (list (message* (send-buf-get* 'out_c_val))
                         'out_c_bal
                         (send-buf-next* 'out_c_val))
                   (and* (empty?* 'out_c)
                         (and* (send-buf-empty?* 'out_c_bal)
                               (and* (not* (send-buf-empty?* 'out_c_val))
                                     (=* 'phase 6))))))))
      ;; 25 Phase 6->7
      (:=* (list 'in_a_bal
                 'in_b_bal
                 'in_c_bal
                 'in_a_val
                 'in_b_val
                 'in_c_val
                 'phase)
           (case*
            (list (cons (list (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              (empty-recv-buf* 8)
                              7)
                        (and* (send-buf-empty?* 'out_a_val)
                              (and* (send-buf-empty?* 'out_b_val)
                                    (and* (send-buf-empty?* 'out_c_val)
                                          (=* 'phase 6))))))))
      ;; Phase 7: receive vote replies from acceptors
      (:=* (list 'in_a
                 'in_a_bal
                 'in_a_val)
           (case*
            (list
             ;; 26
             (cons (list 'empty
                         (recv-buf-put* 'in_a_bal (value* 'in_a))
                         'in_a_val)
                   (and* (full?* 'in_a)
                         (and* (not* (recv-buf-full?* 'in_a_bal))
                               (=* 'phase 7))))
             ;; 27
             (cons (list 'empty
                         'in_a_bal
                         (recv-buf-put* 'in_a_val (value* 'in_a)))
                   (and* (full?* 'in_a)
                         (and* (recv-buf-full?* 'in_a_bal)
                               (and* (not* (recv-buf-full?* 'in_a_val))
                                     (=* 'phase 7))))))))
      (:=* (list 'in_b
                 'in_b_bal
                 'in_b_val)
           (case*
            (list
             ;; 28
             (cons (list 'empty
                         (recv-buf-put* 'in_b_bal (value* 'in_b))
                         'in_b_val)
                   (and* (full?* 'in_b)
                         (and* (not* (recv-buf-full?* 'in_b_bal))
                               (=* 'phase 7))))
             ;; 29
             (cons (list 'empty
                         'in_b_bal
                         (recv-buf-put* 'in_b_val (value* 'in_b)))
                   (and* (full?* 'in_b)
                         (and* (recv-buf-full?* 'in_b_bal)
                               (and* (not* (recv-buf-full?* 'in_b_val))
                                     (=* 'phase 7))))))))
      (:=* (list 'in_c
                 'in_c_bal
                 'in_c_val)
           (case*
            (list
             ;; 30
             (cons (list 'empty
                         (recv-buf-put* 'in_c_bal (value* 'in_c))
                         'in_c_val)
                   (and* (full?* 'in_c)
                         (and* (not* (recv-buf-full?* 'in_c_bal))
                               (=* 'phase 7))))
             ;; 31
             (cons (list 'empty
                         'in_c_bal
                         (recv-buf-put* 'in_c_val (value* 'in_c)))
                   (and* (full?* 'in_c)
                         (and* (recv-buf-full?* 'in_c_bal)
                               (and* (not* (recv-buf-full?* 'in_c_val))
                                     (=* 'phase 7))))))))
      ;; 32 Phase 7->8
      (:=* (list 'a_mbal
                 'b_mbal
                 'c_mbal
                 'a_mval
                 'b_mval
                 'c_mval
                 'phase)
           (case*
            (list (cons (list (recv-buf->nat* 'in_a_bal)
                              (recv-buf->nat* 'in_b_bal)
                              (recv-buf->nat* 'in_c_bal)
                              (recv-buf->nat* 'in_a_val)
                              (recv-buf->nat* 'in_b_val)
                              (recv-buf->nat* 'in_c_val)
                              8)
                        (and* (recv-buf-full?* 'in_a_val)
                              (and* (recv-buf-full?* 'in_b_val)
                                    (and* (recv-buf-full?* 'in_c_val)
                                          (=* 'phase 7))))))))
      ;; Phase 8: check value
      (:=* (list 'phase)
           (case*
            (list
             ;; 33
             (cons (list 0)
                   (and* (=* 'value 'a_mval)
                         (and* (=* 'value 'b_mval)
                               (and* (=* 'value 'c_mval)
                                     (=* 'phase 8)))))
             ;; 34
             (cons (list 255)
                   (and* (not* (and* (=* 'value 'a_mval)
                                     (and* (=* 'value 'b_mval)
                                           (=* 'value 'c_mval))))
                         (=* 'phase 8)))))))))))

;; Model a Paxos acceptor

(define acceptor
  (unity*
   (declare*
    (list (cons 'ballot 'natural)
          (cons 'value 'natural)
          (cons 'phase 'natural)
          (cons 'prom_bal 'natural)
          (cons 'prop_mbal 'natural)
          (cons 'prop_mval 'natural)
          (cons 'out_prop 'send-channel)
          (cons 'in_prop 'recv-channel)
          (cons 'out_prop_bal 'send-buf)
          (cons 'out_prop_val 'send-buf)
          (cons 'in_prop_bal 'recv-buf)
          (cons 'in_prop_val 'recv-buf)))
   (initially*
    (list
     (:=* (list 'ballot
                'value
                'phase
                'prom_bal
                'out_prop
                'in_prop_bal)
          (list 0
                0
                1
                0
                'empty
                (empty-recv-buf* 8)))))
   (assign*
    (list
     (list
      ;; Phase 0: Accepting state
      ;; Phase 255: Failure state
      ;; Phase 1->2: prepare receive buffers
      (:=* (list 'in_prop_bal
                 'phase)
           (case*
            (list
             (cons (list (empty-recv-buf* 8)
                         2)
                   (=* 'phase 1)))))
      ;; Phase 2: receive proposal ballot from proposer
      (:=* (list 'in_prop
                 'in_prop_bal)
           (case*
            (list
             (cons (list 'empty
                         (recv-buf-put* 'in_prop_bal (value* 'in_prop)))
                   (and* (full?* 'in_prop)
                         (and* (not* (recv-buf-full?* 'in_prop_bal))
                               (=* 'phase 2)))))))
      ;; Phase 2->3: read proposal
      (:=* (list 'prop_mbal
                 'phase)
           (case*
            (list
             (cons (list (recv-buf->nat* 'in_prop_bal)
                         3)
                   (and* (recv-buf-full?* 'in_prop_bal)
                         (=* 'phase 2))))))
      ;; Phase 3->4: prepare promise response
      ;; Proposed ballot # > 'ballot and > 'prom_bal
      (:=* (list 'out_prop_bal
                 'out_prop_val
                 'prom_bal
                 'phase)
           (case*
            (list
             (cons (list (nat->send-buf* 8 'ballot)
                         (nat->send-buf* 8 'value)
                         'prop_mbal
                         4)
                   (and* (<* 'ballot
                             'prop_mbal)
                         (and* (<* 'prom_bal
                                   'prop_mbal)
                               (=* 'phase 3)))))))
      ;; Phase 4: send promise message
      (:=* (list 'out_prop
                 'out_prop_bal
                 'out_prop_val)
           (case*
            (list
             (cons (list (message* (send-buf-get* 'out_prop_bal))
                         (send-buf-next* 'out_prop_bal)
                         'out_prop_val)
                   (and* (empty?* 'out_prop)
                         (and* (not* (send-buf-empty?* 'out_prop_bal))
                               (=* 'phase 4))))
             (cons (list (message* (send-buf-get* 'out_prop_val))
                         'out_prop_bal
                         (send-buf-next* 'out_prop_val))
                   (and* (empty?* 'out_prop)
                         (and* (send-buf-empty?* 'out_prop_bal)
                               (and* (not* (send-buf-empty?* 'out_prop_val))
                                     (=* 'phase 4))))))))
      ;; Phase 4->5: prepare to receive accept message
      (:=* (list 'in_prop_bal
                 'in_prop_val
                 'phase)
           (case*
            (list
             (cons (list (empty-recv-buf* 8)
                         (empty-recv-buf* 8)
                         5)
                   (and* (send-buf-empty?* 'out_prop_val)
                         (=* 'phase 4))))))
      ;; Phase 5: receive accept ballot/value from proposer
      (:=* (list 'in_prop
                 'in_prop_bal
                 'in_prop_val)
           (case*
            (list
             (cons (list 'empty
                         (recv-buf-put* 'in_prop_bal (value* 'in_prop))
                         'in_prop_val)
                   (and* (full?* 'in_prop)
                         (and* (not* (recv-buf-full?* 'in_prop_bal))
                               (=* 'phase 5))))
             (cons (list 'empty
                         'in_prop_bal
                         (recv-buf-put* 'in_prop_val (value* 'in_prop)))
                   (and* (full?* 'in_prop)
                         (and* (recv-buf-full?* 'in_prop_bal)
                               (and* (not* (recv-buf-full?* 'in_prop_val))
                                     (=* 'phase 5))))))))
      ;; Phase 5->6: read accept
      (:=* (list 'prop_mbal
                 'prop_mval
                 'phase)
           (case*
            (list
             (cons (list (recv-buf->nat* 'in_prop_bal)
                         (recv-buf->nat* 'in_prop_val)
                         6)
                   (and* (recv-buf-full?* 'in_prop_val)
                         (=* 'phase 5))))))
      ;; Phase 6->7: check validity of accept
      (:=* (list 'ballot
                 'value
                 'out_prop_bal
                 'out_prop_val
                 'phase)
           (case*
            (list
             (cons (list 'prop_mbal
                         'prop_mval
                         (nat->send-buf* 8 'prop_mbal)
                         (nat->send-buf* 8 'prop_mval)
                         7)
                   (and* (=* 'prop_mbal 'prom_bal)
                         (=* 'phase 6))))))
      ;; Phase 7: send accept acknowledged message
      (:=* (list 'out_prop
                 'out_prop_bal
                 'out_prop_val)
           (case*
            (list
             (cons (list (message* (send-buf-get* 'out_prop_bal))
                         (send-buf-next* 'out_prop_bal)
                         'out_prop_val)
                   (and* (empty?* 'out_prop)
                         (and* (not* (send-buf-empty?* 'out_prop_bal))
                               (=* 'phase 7))))
             (cons (list (message* (send-buf-get* 'out_prop_val))
                         'out_prop_bal
                         (send-buf-next* 'out_prop_val))
                   (and* (empty?* 'out_prop)
                         (and* (send-buf-empty?* 'out_prop_bal)
                               (and* (not* (send-buf-empty?* 'out_prop_val))
                                     (=* 'phase 7))))))))
      ;; Phase 7->0: complete
      (:=* (list 'phase)
           (case*
            (list
             (cons (list 0)
                   (and* (send-buf-empty?* 'out_prop_val)
                         (=* 'phase 7)))))))))))

(define mini-test
  (unity*
   (declare*
    (list (cons 'ballot 'natural)
          (cons 'value 'natural)
          (cons 'phase 'natural)
          (cons 'prom_bal 'natural)
          (cons 'prop_mbal 'natural)
          (cons 'prop_mval 'natural)
          (cons 'out_prop 'send-channel)
          (cons 'in_prop 'recv-channel)
          (cons 'out_prop_bal 'send-buf)
          (cons 'out_prop_val 'send-buf)
          (cons 'in_prop_bal 'recv-buf)
          (cons 'in_prop_val 'recv-buf)))
   (initially*
    (list
     (:=*
      (list 'phase)
      (list 0))))
   (assign*
    (list
     (list
      ;; Phase 2: receive proposal ballot from proposer
      (:=* (list 'in_prop
                 'in_prop_bal)
           (case*
            (list
             (cons (list 'empty
                         (recv-buf-put* 'in_prop_bal (value* 'in_prop)))
                   (and* (full?* 'in_prop)
                         (and* (not* (recv-buf-full?* 'in_prop_bal))
                               (=* 'phase 2))))))))))))

(provide proposer
         acceptor
         mini-test)
