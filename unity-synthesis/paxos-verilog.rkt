#lang rosette/safe

(require "config.rkt"
         "paxos.rkt"
         "synth.rkt"
         "verilog/backend.rkt"
         "verilog/mapping.rkt"
         "verilog/syntax.rkt"
         "verilog/synth.rkt"
         "verilog/verify.rkt"
         rosette/lib/value-browser)

;; cpu time: 1034988 real time: 7294801 gc time: 142711
(define proposer-impl
  (verilog-module*
   'proposer
   '(d15 d16 d17 d12 d13 d14 d9 d10 d11 d6 d7 d8 d3 d4 d5 d0 d1 d2 clock reset)
   (list
    (reg* 32 'in_c_val_rcvd)
    (reg* 32 'in_c_val_vals)
    (reg* 32 'in_b_val_rcvd)
    (reg* 32 'in_b_val_vals)
    (reg* 32 'in_a_val_rcvd)
    (reg* 32 'in_a_val_vals)
    (reg* 32 'in_c_bal_rcvd)
    (reg* 32 'in_c_bal_vals)
    (reg* 32 'in_b_bal_rcvd)
    (reg* 32 'in_b_bal_vals)
    (reg* 32 'in_a_bal_rcvd)
    (reg* 32 'in_a_bal_vals)
    (reg* 32 'out_c_val_sent)
    (reg* 32 'out_c_val_vals)
    (reg* 32 'out_b_val_sent)
    (reg* 32 'out_b_val_vals)
    (reg* 32 'out_a_val_sent)
    (reg* 32 'out_a_val_vals)
    (reg* 32 'out_c_bal_sent)
    (reg* 32 'out_c_bal_vals)
    (reg* 32 'out_b_bal_sent)
    (reg* 32 'out_b_bal_vals)
    (reg* 32 'out_a_bal_sent)
    (reg* 32 'out_a_bal_vals)
    (input* (wire* 1 'd15))
    (output* (reg* 1 'd16))
    (input* (wire* 1 'd17))
    (input* (wire* 1 'd12))
    (output* (reg* 1 'd13))
    (input* (wire* 1 'd14))
    (input* (wire* 1 'd9))
    (output* (reg* 1 'd10))
    (input* (wire* 1 'd11))
    (output* (reg* 1 'd6))
    (input* (wire* 1 'd7))
    (output* (reg* 1 'd8))
    (output* (reg* 1 'd3))
    (input* (wire* 1 'd4))
    (output* (reg* 1 'd5))
    (output* (reg* 1 'd0))
    (input* (wire* 1 'd1))
    (output* (reg* 1 'd2))
    (reg* 32 'c_mval)
    (reg* 32 'b_mval)
    (reg* 32 'a_mval)
    (reg* 32 'c_mbal)
    (reg* 32 'b_mbal)
    (reg* 32 'a_mbal)
    (reg* 32 'phase)
    (reg* 32 'value)
    (reg* 32 'ballot)
    (input* (wire* 1 'clock))
    (input* (wire* 1 'reset)))
   (list
    (always*
     (or* (posedge* 'clock) (posedge* 'reset))
     (list
      (if*
       'reset
       (list
        (<=* 'ballot (bv #x00000001 32))
        (<=* 'value (bv #x00000020 32))
        (<=* 'phase (bv #x00000001 32)))
       (list
        (if*
         (bweq* (bv #x000000ff 32) 'ballot)
         (list (<=* 'phase 'ballot))
         (list
          (if*
           (bweq* (bv #x00000001 32) 'phase)
           (list
            (<=* 'out_a_bal_vals 'ballot)
            (<=* 'out_a_bal_sent (bv #x00000000 32))
            (<=* 'out_b_bal_vals 'ballot)
            (<=* 'out_b_bal_sent (bv #x00000000 32))
            (<=* 'out_c_bal_vals 'ballot)
            (<=* 'out_c_bal_sent (bv #x00000000 32))
            (<=* 'phase (bv #x00000002 32)))
           (list
            (if*
             (and*
              (and*
               (not* (lt* (bv #x0000001f 32) 'out_a_bal_sent))
               (bweq* (bv #x00000002 32) 'phase))
              (eq* 'd1 'd0))
             (list
              (<=*
               'd2
               (eq*
                (bwand*
                 (shr* 'out_a_bal_vals 'out_a_bal_sent)
                 (bv #x00000001 32))
                (bv #x00000001 32)))
              (<=* 'd0 (not* 'd0))
              (<=* 'out_a_bal_vals 'out_a_bal_vals)
              (<=* 'out_a_bal_sent (add* 'out_a_bal_sent (bv #x00000001 32))))
             (list
              (if*
               (and*
                (eq* 'd4 'd3)
                (and*
                 (lt* 'out_b_bal_sent (bv #x00000020 32))
                 (bweq* (bv #x00000002 32) 'phase)))
               (list
                (<=*
                 'd5
                 (eq*
                  (bwand*
                   (bv #x00000001 32)
                   (shr* 'out_b_bal_vals 'out_b_bal_sent))
                  (bv #x00000001 32)))
                (<=* 'd3 (not* 'd3))
                (<=* 'out_b_bal_vals 'out_b_bal_vals)
                (<=* 'out_b_bal_sent (add* 'out_b_bal_sent (bv #x00000001 32))))
               (list
                (if*
                 (and*
                  (not* (or* (and* (not* 'd7) 'd6) (and* (eq* #f 'd6) 'd7)))
                  (and*
                   (bweq* 'phase (bv #x00000002 32))
                   (lt* 'out_c_bal_sent (bv #x00000020 32))))
                 (list
                  (<=*
                   'd8
                   (eq*
                    (bwand*
                     (shr* 'out_c_bal_vals 'out_c_bal_sent)
                     (bv #x00000001 32))
                    (bv #x00000001 32)))
                  (<=* 'd6 (not* 'd6))
                  (<=* 'out_c_bal_vals 'out_c_bal_vals)
                  (<=*
                   'out_c_bal_sent
                   (add* (bv #x00000001 32) 'out_c_bal_sent)))
                 (list
                  (if*
                   (and*
                    (and*
                     (lt* (bv #x0000001f 32) 'out_b_bal_sent)
                     (and*
                      (bweq* 'phase (bv #x00000002 32))
                      (lt* (bv #x0000001f 32) 'out_c_bal_sent)))
                    (lt* (bv #x0000001f 32) 'out_a_bal_sent))
                   (list
                    (<=* 'in_a_bal_vals (bv #x00000000 32))
                    (<=* 'in_a_bal_rcvd (bv #x00000000 32))
                    (<=* 'in_b_bal_vals (bv #x00000000 32))
                    (<=* 'in_b_bal_rcvd (bv #x00000000 32))
                    (<=* 'in_c_bal_vals (bv #x00000000 32))
                    (<=* 'in_c_bal_rcvd (bv #x00000000 32))
                    (<=* 'in_a_val_vals (bv #x00000000 32))
                    (<=* 'in_a_val_rcvd (bv #x00000000 32))
                    (<=* 'in_b_val_vals (bv #x00000000 32))
                    (<=* 'in_b_val_rcvd (bv #x00000000 32))
                    (<=* 'in_c_val_vals (bv #x00000000 32))
                    (<=* 'in_c_val_rcvd (bv #x00000000 32))
                    (<=* 'phase (bv #x00000003 32)))
                   (list
                    (if*
                     (and*
                      (or* (and* 'd9 (not* 'd10)) (and* (eq* 'd9 #f) 'd10))
                      (and*
                       (eq* (lt* (bv #x0000001f 32) 'in_a_bal_rcvd) #f)
                       (bweq* 'phase (bv #x00000003 32))))
                     (list
                      (<=* 'd10 'd9)
                      (<=*
                       'in_a_bal_vals
                       (bwxor*
                        (bwor*
                         (bwxor* 'in_a_bal_vals (bv #xffffffff 32))
                         (shl* (bv #x00000001 32) 'in_a_bal_rcvd))
                        (bwnot* (shl* (bool->vect* 'd11) 'in_a_bal_rcvd))))
                      (<=*
                       'in_a_bal_rcvd
                       (add* 'in_a_bal_rcvd (bv #x00000001 32)))
                      (<=* 'in_a_val_vals 'in_a_val_vals)
                      (<=* 'in_a_val_rcvd 'in_a_val_rcvd))
                     (list
                      (if*
                       (and*
                        (and*
                         (lt* (bv #x0000001f 32) 'in_a_bal_rcvd)
                         (and*
                          (not* (lt* (bv #x0000001f 32) 'in_a_val_rcvd))
                          (bweq* 'phase (bv #x00000003 32))))
                        (or* (and* (not* 'd10) 'd9) (and* 'd10 (eq* #f 'd9))))
                       (list
                        (<=* 'd10 'd9)
                        (<=* 'in_a_bal_vals 'in_a_bal_vals)
                        (<=* 'in_a_bal_rcvd 'in_a_bal_rcvd)
                        (<=*
                         'in_a_val_vals
                         (bwxor*
                          (bwnot* (shl* (bool->vect* 'd11) 'in_a_val_rcvd))
                          (bwor*
                           (bwnot* 'in_a_val_vals)
                           (shl* (bv #x00000001 32) 'in_a_val_rcvd))))
                        (<=*
                         'in_a_val_rcvd
                         (add* (bv #x00000001 32) 'in_a_val_rcvd)))
                       (list
                        (if*
                         (and*
                          (or* (and* (not* 'd13) 'd12) (and* 'd13 (eq* #f 'd12)))
                          (and*
                           (bweq* 'phase (bv #x00000003 32))
                           (not* (lt* (bv #x0000001f 32) 'in_b_bal_rcvd))))
                         (list
                          (<=* 'd13 'd12)
                          (<=*
                           'in_b_bal_vals
                           (bwxor*
                            (bwor*
                             (bwxor* 'in_b_bal_vals (bv #xffffffff 32))
                             (shl* (bv #x00000001 32) 'in_b_bal_rcvd))
                            (bwnot* (shl* (bool->vect* 'd14) 'in_b_bal_rcvd))))
                          (<=*
                           'in_b_bal_rcvd
                           (add* 'in_b_bal_rcvd (bv #x00000001 32)))
                          (<=* 'in_b_val_vals 'in_b_val_vals)
                          (<=* 'in_b_val_rcvd 'in_b_val_rcvd))
                         (list
                          (if*
                           (and*
                            (or*
                             (and* 'd13 (eq* 'd12 #f))
                             (and* (eq* #f 'd13) 'd12))
                            (and*
                             (lt* (bv #x0000001f 32) 'in_b_bal_rcvd)
                             (and*
                              (bweq* (bv #x00000003 32) 'phase)
                              (lt* 'in_b_val_rcvd (bv #x00000020 32)))))
                           (list
                            (<=* 'd13 'd12)
                            (<=* 'in_b_bal_vals 'in_b_bal_vals)
                            (<=* 'in_b_bal_rcvd 'in_b_bal_rcvd)
                            (<=*
                             'in_b_val_vals
                             (bwxor*
                              (bwnot* (shl* (bool->vect* 'd14) 'in_b_val_rcvd))
                              (bwor*
                               (shl* (bv #x00000001 32) 'in_b_val_rcvd)
                               (bwnot* 'in_b_val_vals))))
                            (<=*
                             'in_b_val_rcvd
                             (add* 'in_b_val_rcvd (bv #x00000001 32))))
                           (list
                            (if*
                             (and*
                              (and*
                               (not* (lt* (bv #x0000001f 32) 'in_c_bal_rcvd))
                               (bweq* 'phase (bv #x00000003 32)))
                              (or*
                               (and* 'd16 (not* 'd15))
                               (and* (eq* #f 'd16) 'd15)))
                             (list
                              (<=* 'd16 'd15)
                              (<=*
                               'in_c_bal_vals
                               (bwxor*
                                (bwnot* (shl* (bool->vect* 'd17) 'in_c_bal_rcvd))
                                (bwor*
                                 (shl* (bv #x00000001 32) 'in_c_bal_rcvd)
                                 (bwnot* 'in_c_bal_vals))))
                              (<=*
                               'in_c_bal_rcvd
                               (add* (bv #x00000001 32) 'in_c_bal_rcvd))
                              (<=* 'in_c_val_vals 'in_c_val_vals)
                              (<=* 'in_c_val_rcvd 'in_c_val_rcvd))
                             (list
                              (if*
                               (and*
                                (and*
                                 (and*
                                  (eq*
                                   (lt* (bv #x0000001f 32) 'in_c_val_rcvd)
                                   #f)
                                  (bweq* (bv #x00000003 32) 'phase))
                                 (lt* (bv #x0000001f 32) 'in_c_bal_rcvd))
                                (or*
                                 (and* (not* 'd16) 'd15)
                                 (and* (eq* #f 'd15) 'd16)))
                               (list
                                (<=* 'd16 'd15)
                                (<=* 'in_c_bal_vals 'in_c_bal_vals)
                                (<=* 'in_c_bal_rcvd 'in_c_bal_rcvd)
                                (<=*
                                 'in_c_val_vals
                                 (bwxor*
                                  (bwor*
                                   (bwxor* 'in_c_val_vals (bv #xffffffff 32))
                                   (shl* (bv #x00000001 32) 'in_c_val_rcvd))
                                  (bwnot*
                                   (shl* (bool->vect* 'd17) 'in_c_val_rcvd))))
                                (<=*
                                 'in_c_val_rcvd
                                 (add* 'in_c_val_rcvd (bv #x00000001 32))))
                               (list
                                (if*
                                 (and*
                                  (and*
                                   (and*
                                    (lt* (bv #x0000001f 32) 'in_c_val_rcvd)
                                    (bweq* (bv #x00000003 32) 'phase))
                                   (lt* (bv #x0000001f 32) 'in_b_val_rcvd))
                                  (lt* (bv #x0000001f 32) 'in_a_val_rcvd))
                                 (list
                                  (<=* 'a_mbal 'in_a_bal_vals)
                                  (<=* 'b_mbal 'in_b_bal_vals)
                                  (<=* 'c_mbal 'in_c_bal_vals)
                                  (<=* 'a_mval 'in_a_val_vals)
                                  (<=* 'b_mval 'in_b_val_vals)
                                  (<=* 'c_mval 'in_c_val_vals)
                                  (<=* 'phase (bv #x00000004 32)))
                                 (list
                                  (if*
                                   (and*
                                    (and*
                                     (and*
                                      (bweq* (bv #x00000004 32) 'phase)
                                      (bweq* (bv #x00000000 32) 'c_mbal))
                                     (bweq* (bv #x00000000 32) 'b_mbal))
                                    (bweq* (bv #x00000000 32) 'a_mbal))
                                   (list
                                    (<=* 'value 'value)
                                    (<=* 'phase (bv #x00000005 32)))
                                   (list
                                    (if*
                                     (and*
                                      (or*
                                       (bweq* 'a_mbal 'b_mbal)
                                       (lt* 'b_mbal 'a_mbal))
                                      (and*
                                       (bweq* 'phase (bv #x00000004 32))
                                       (or*
                                        (lt* 'c_mbal 'a_mbal)
                                        (bweq* 'a_mbal 'c_mbal))))
                                     (list
                                      (<=* 'value 'a_mval)
                                      (<=* 'phase (bv #x00000005 32)))
                                     (list
                                      (if*
                                       (and*
                                        (or*
                                         (bweq* 'b_mbal 'c_mbal)
                                         (lt* 'c_mbal 'b_mbal))
                                        (bweq* (bv #x00000004 32) 'phase))
                                       (list
                                        (<=* 'value 'b_mval)
                                        (<=* 'phase (bv #x00000005 32)))
                                       (list
                                        (if*
                                         (bweq* (bv #x00000004 32) 'phase)
                                         (list
                                          (<=* 'value 'c_mval)
                                          (<=* 'phase (bv #x00000005 32)))
                                         (list
                                          (if*
                                           (bweq* 'phase (bv #x00000005 32))
                                           (list
                                            (<=* 'out_a_bal_vals 'ballot)
                                            (<=*
                                             'out_a_bal_sent
                                             (bv #x00000000 32))
                                            (<=* 'out_b_bal_vals 'ballot)
                                            (<=*
                                             'out_b_bal_sent
                                             (bv #x00000000 32))
                                            (<=* 'out_c_bal_vals 'ballot)
                                            (<=*
                                             'out_c_bal_sent
                                             (bv #x00000000 32))
                                            (<=* 'out_a_val_vals 'value)
                                            (<=*
                                             'out_a_val_sent
                                             (bv #x00000000 32))
                                            (<=* 'out_b_val_vals 'value)
                                            (<=*
                                             'out_b_val_sent
                                             (bv #x00000000 32))
                                            (<=* 'out_c_val_vals 'value)
                                            (<=*
                                             'out_c_val_sent
                                             (bv #x00000000 32))
                                            (<=* 'phase (bv #x00000006 32)))
                                           (list
                                            (if*
                                             (and*
                                              (not*
                                               (or*
                                                (and* (eq* 'd1 #f) 'd0)
                                                (and* (not* 'd0) 'd1)))
                                              (and*
                                               (bweq* 'phase (bv #x00000006 32))
                                               (not*
                                                (lt*
                                                 (bv #x0000001f 32)
                                                 'out_a_bal_sent))))
                                             (list
                                              (<=*
                                               'd2
                                               (eq*
                                                (bwand*
                                                 (shr*
                                                  'out_a_bal_vals
                                                  'out_a_bal_sent)
                                                 (bv #x00000001 32))
                                                (bv #x00000001 32)))
                                              (<=* 'd0 (eq* 'd1 #f))
                                              (<=*
                                               'out_a_bal_vals
                                               'out_a_bal_vals)
                                              (<=*
                                               'out_a_bal_sent
                                               (add*
                                                (bv #x00000001 32)
                                                'out_a_bal_sent))
                                              (<=*
                                               'out_a_val_vals
                                               'out_a_val_vals)
                                              (<=*
                                               'out_a_val_sent
                                               'out_a_val_sent))
                                             (list
                                              (if*
                                               (and*
                                                (and*
                                                 (lt*
                                                  (bv #x0000001f 32)
                                                  'out_a_bal_sent)
                                                 (and*
                                                  (not*
                                                   (lt*
                                                    (bv #x0000001f 32)
                                                    'out_a_val_sent))
                                                  (bweq*
                                                   (bv #x00000006 32)
                                                   'phase)))
                                                (not*
                                                 (or*
                                                  (and* 'd1 (eq* #f 'd0))
                                                  (and* 'd0 (not* 'd1)))))
                                               (list
                                                (<=*
                                                 'd2
                                                 (eq*
                                                  (bwand*
                                                   (shr*
                                                    'out_a_val_vals
                                                    'out_a_val_sent)
                                                   (bv #x00000001 32))
                                                  (bv #x00000001 32)))
                                                (<=* 'd0 (not* 'd0))
                                                (<=*
                                                 'out_a_bal_vals
                                                 'out_a_bal_vals)
                                                (<=*
                                                 'out_a_bal_sent
                                                 'out_a_bal_sent)
                                                (<=*
                                                 'out_a_val_vals
                                                 'out_a_val_vals)
                                                (<=*
                                                 'out_a_val_sent
                                                 (add*
                                                  (bv #x00000001 32)
                                                  'out_a_val_sent)))
                                               (list
                                                (if*
                                                 (and*
                                                  (eq* 'd3 'd4)
                                                  (and*
                                                   (bweq*
                                                    'phase
                                                    (bv #x00000006 32))
                                                   (not*
                                                    (lt*
                                                     (bv #x0000001f 32)
                                                     'out_b_bal_sent))))
                                                 (list
                                                  (<=*
                                                   'd5
                                                   (eq*
                                                    (bwand*
                                                     (bv #x00000001 32)
                                                     (shr*
                                                      'out_b_bal_vals
                                                      'out_b_bal_sent))
                                                    (bv #x00000001 32)))
                                                  (<=* 'd3 (not* 'd4))
                                                  (<=*
                                                   'out_b_bal_vals
                                                   'out_b_bal_vals)
                                                  (<=*
                                                   'out_b_bal_sent
                                                   (add*
                                                    'out_b_bal_sent
                                                    (bv #x00000001 32)))
                                                  (<=*
                                                   'out_b_val_vals
                                                   'out_b_val_vals)
                                                  (<=*
                                                   'out_b_val_sent
                                                   'out_b_val_sent))
                                                 (list
                                                  (if*
                                                   (and*
                                                    (and*
                                                     (and*
                                                      (bweq*
                                                       (bv #x00000006 32)
                                                       'phase)
                                                      (lt*
                                                       'out_b_val_sent
                                                       (bv #x00000020 32)))
                                                     (lt*
                                                      (bv #x0000001f 32)
                                                      'out_b_bal_sent))
                                                    (eq*
                                                     (or*
                                                      (and* 'd3 (not* 'd4))
                                                      (and* 'd4 (not* 'd3)))
                                                     #f))
                                                   (list
                                                    (<=*
                                                     'd5
                                                     (eq*
                                                      (bwand*
                                                       (shr*
                                                        'out_b_val_vals
                                                        'out_b_val_sent)
                                                       (bv #x00000001 32))
                                                      (bv #x00000001 32)))
                                                    (<=* 'd3 (not* 'd3))
                                                    (<=*
                                                     'out_b_bal_vals
                                                     'out_b_bal_vals)
                                                    (<=*
                                                     'out_b_bal_sent
                                                     'out_b_bal_sent)
                                                    (<=*
                                                     'out_b_val_vals
                                                     'out_b_val_vals)
                                                    (<=*
                                                     'out_b_val_sent
                                                     (add*
                                                      'out_b_val_sent
                                                      (bv #x00000001 32))))
                                                   (list
                                                    (if*
                                                     (and*
                                                      (and*
                                                       (not*
                                                        (lt*
                                                         (bv #x0000001f 32)
                                                         'out_c_bal_sent))
                                                       (bweq*
                                                        'phase
                                                        (bv #x00000006 32)))
                                                      (eq* 'd7 'd6))
                                                     (list
                                                      (<=*
                                                       'd8
                                                       (eq*
                                                        (bwand*
                                                         (shr*
                                                          'out_c_bal_vals
                                                          'out_c_bal_sent)
                                                         (bv #x00000001 32))
                                                        (bv #x00000001 32)))
                                                      (<=* 'd6 (not* 'd6))
                                                      (<=*
                                                       'out_c_bal_vals
                                                       'out_c_bal_vals)
                                                      (<=*
                                                       'out_c_bal_sent
                                                       (add*
                                                        (bv #x00000001 32)
                                                        'out_c_bal_sent))
                                                      (<=*
                                                       'out_c_val_vals
                                                       'out_c_val_vals)
                                                      (<=*
                                                       'out_c_val_sent
                                                       'out_c_val_sent))
                                                     (list
                                                      (if*
                                                       (and*
                                                        (not*
                                                         (or*
                                                          (and* 'd7 (eq* #f 'd6))
                                                          (and*
                                                           'd6
                                                           (eq* #f 'd7))))
                                                        (and*
                                                         (and*
                                                          (eq*
                                                           #f
                                                           (lt*
                                                            (bv #x0000001f 32)
                                                            'out_c_val_sent))
                                                          (bweq*
                                                           'phase
                                                           (bv #x00000006 32)))
                                                         (lt*
                                                          (bv #x0000001f 32)
                                                          'out_c_bal_sent)))
                                                       (list
                                                        (<=*
                                                         'd8
                                                         (eq*
                                                          (bwand*
                                                           (shr*
                                                            'out_c_val_vals
                                                            'out_c_val_sent)
                                                           (bv #x00000001 32))
                                                          (bv #x00000001 32)))
                                                        (<=* 'd6 (not* 'd6))
                                                        (<=*
                                                         'out_c_bal_vals
                                                         'out_c_bal_vals)
                                                        (<=*
                                                         'out_c_bal_sent
                                                         'out_c_bal_sent)
                                                        (<=*
                                                         'out_c_val_vals
                                                         'out_c_val_vals)
                                                        (<=*
                                                         'out_c_val_sent
                                                         (add*
                                                          (bv #x00000001 32)
                                                          'out_c_val_sent)))
                                                       (list
                                                        (if*
                                                         (and*
                                                          (and*
                                                           (lt*
                                                            (bv #x0000001f 32)
                                                            'out_b_val_sent)
                                                           (and*
                                                            (bweq*
                                                             (bv #x00000006 32)
                                                             'phase)
                                                            (lt*
                                                             (bv #x0000001f 32)
                                                             'out_c_val_sent)))
                                                          (lt*
                                                           (bv #x0000001f 32)
                                                           'out_a_val_sent))
                                                         (list
                                                          (<=*
                                                           'in_a_bal_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_a_bal_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_b_bal_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_b_bal_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_c_bal_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_c_bal_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_a_val_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_a_val_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_b_val_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_b_val_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_c_val_vals
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'in_c_val_rcvd
                                                           (bv #x00000000 32))
                                                          (<=*
                                                           'phase
                                                           (bv #x00000007 32)))
                                                         (list
                                                          (if*
                                                           (and*
                                                            (or*
                                                             (and*
                                                              (not* 'd10)
                                                              'd9)
                                                             (and*
                                                              'd10
                                                              (not* 'd9)))
                                                            (and*
                                                             (bweq*
                                                              'phase
                                                              (bv #x00000007 32))
                                                             (eq*
                                                              #f
                                                              (lt*
                                                               (bv #x0000001f 32)
                                                               'in_a_bal_rcvd))))
                                                           (list
                                                            (<=* 'd10 'd9)
                                                            (<=*
                                                             'in_a_bal_vals
                                                             (bwxor*
                                                              (bwnot*
                                                               (shl*
                                                                (bool->vect*
                                                                 'd11)
                                                                'in_a_bal_rcvd))
                                                              (bwor*
                                                               (shl*
                                                                (bv #x00000001 32)
                                                                'in_a_bal_rcvd)
                                                               (bwnot*
                                                                'in_a_bal_vals))))
                                                            (<=*
                                                             'in_a_bal_rcvd
                                                             (add*
                                                              'in_a_bal_rcvd
                                                              (bv #x00000001 32)))
                                                            (<=*
                                                             'in_a_val_vals
                                                             'in_a_val_vals)
                                                            (<=*
                                                             'in_a_val_rcvd
                                                             'in_a_val_rcvd))
                                                           (list
                                                            (if*
                                                             (and*
                                                              (or*
                                                               (and*
                                                                'd9
                                                                (not* 'd10))
                                                               (and*
                                                                (eq* #f 'd9)
                                                                'd10))
                                                              (and*
                                                               (and*
                                                                (not*
                                                                 (lt*
                                                                  (bv #x0000001f 32)
                                                                  'in_a_val_rcvd))
                                                                (bweq*
                                                                 'phase
                                                                 (bv #x00000007 32)))
                                                               (lt*
                                                                (bv #x0000001f 32)
                                                                'in_a_bal_rcvd)))
                                                             (list
                                                              (<=* 'd10 'd9)
                                                              (<=*
                                                               'in_a_bal_vals
                                                               'in_a_bal_vals)
                                                              (<=*
                                                               'in_a_bal_rcvd
                                                               'in_a_bal_rcvd)
                                                              (<=*
                                                               'in_a_val_vals
                                                               (bwxor*
                                                                (bwnot*
                                                                 (shl*
                                                                  (bool->vect*
                                                                   'd11)
                                                                  'in_a_val_rcvd))
                                                                (bwor*
                                                                 (shl*
                                                                  (bv #x00000001 32)
                                                                  'in_a_val_rcvd)
                                                                 (bwxor*
                                                                  'in_a_val_vals
                                                                  (bv #xffffffff 32)))))
                                                              (<=*
                                                               'in_a_val_rcvd
                                                               (add*
                                                                'in_a_val_rcvd
                                                                (bv #x00000001 32))))
                                                             (list
                                                              (if*
                                                               (and*
                                                                (or*
                                                                 (and*
                                                                  (not* 'd13)
                                                                  'd12)
                                                                 (and*
                                                                  (not* 'd12)
                                                                  'd13))
                                                                (and*
                                                                 (not*
                                                                  (lt*
                                                                   (bv #x0000001f 32)
                                                                   'in_b_bal_rcvd))
                                                                 (bweq*
                                                                  (bv #x00000007 32)
                                                                  'phase)))
                                                               (list
                                                                (<=* 'd13 'd12)
                                                                (<=*
                                                                 'in_b_bal_vals
                                                                 (bwxor*
                                                                  (bwnot*
                                                                   (shl*
                                                                    (bool->vect*
                                                                     'd14)
                                                                    'in_b_bal_rcvd))
                                                                  (bwor*
                                                                   (shl*
                                                                    (bv #x00000001 32)
                                                                    'in_b_bal_rcvd)
                                                                   (bwnot*
                                                                    'in_b_bal_vals))))
                                                                (<=*
                                                                 'in_b_bal_rcvd
                                                                 (add*
                                                                  'in_b_bal_rcvd
                                                                  (bv #x00000001 32)))
                                                                (<=*
                                                                 'in_b_val_vals
                                                                 'in_b_val_vals)
                                                                (<=*
                                                                 'in_b_val_rcvd
                                                                 'in_b_val_rcvd))
                                                               (list
                                                                (if*
                                                                 (and*
                                                                  (or*
                                                                   (and*
                                                                    (eq* #f 'd12)
                                                                    'd13)
                                                                   (and*
                                                                    (eq* 'd13 #f)
                                                                    'd12))
                                                                  (and*
                                                                   (and*
                                                                    (bweq*
                                                                     'phase
                                                                     (bv #x00000007 32))
                                                                    (eq*
                                                                     #f
                                                                     (lt*
                                                                      (bv #x0000001f 32)
                                                                      'in_b_val_rcvd)))
                                                                   (lt*
                                                                    (bv #x0000001f 32)
                                                                    'in_b_bal_rcvd)))
                                                                 (list
                                                                  (<=* 'd13 'd12)
                                                                  (<=*
                                                                   'in_b_bal_vals
                                                                   'in_b_bal_vals)
                                                                  (<=*
                                                                   'in_b_bal_rcvd
                                                                   'in_b_bal_rcvd)
                                                                  (<=*
                                                                   'in_b_val_vals
                                                                   (bwxor*
                                                                    (bwnot*
                                                                     (shl*
                                                                      (bool->vect*
                                                                       'd14)
                                                                      'in_b_val_rcvd))
                                                                    (bwor*
                                                                     (shl*
                                                                      (bv #x00000001 32)
                                                                      'in_b_val_rcvd)
                                                                     (bwxor*
                                                                      (bv #xffffffff 32)
                                                                      'in_b_val_vals))))
                                                                  (<=*
                                                                   'in_b_val_rcvd
                                                                   (add*
                                                                    'in_b_val_rcvd
                                                                    (bv #x00000001 32))))
                                                                 (list
                                                                  (if*
                                                                   (and*
                                                                    (and*
                                                                     (not*
                                                                      (lt*
                                                                       (bv #x0000001f 32)
                                                                       'in_c_bal_rcvd))
                                                                     (bweq*
                                                                      'phase
                                                                      (bv #x00000007 32)))
                                                                    (or*
                                                                     (and*
                                                                      (not* 'd16)
                                                                      'd15)
                                                                     (and*
                                                                      'd16
                                                                      (not*
                                                                       'd15))))
                                                                   (list
                                                                    (<=*
                                                                     'd16
                                                                     'd15)
                                                                    (<=*
                                                                     'in_c_bal_vals
                                                                     (bwxor*
                                                                      (bwor*
                                                                       (bwnot*
                                                                        'in_c_bal_vals)
                                                                       (shl*
                                                                        (bv #x00000001 32)
                                                                        'in_c_bal_rcvd))
                                                                      (bwxor*
                                                                       (shl*
                                                                        (bool->vect*
                                                                         'd17)
                                                                        'in_c_bal_rcvd)
                                                                       (bv #xffffffff 32))))
                                                                    (<=*
                                                                     'in_c_bal_rcvd
                                                                     (add*
                                                                      'in_c_bal_rcvd
                                                                      (bv #x00000001 32)))
                                                                    (<=*
                                                                     'in_c_val_vals
                                                                     'in_c_val_vals)
                                                                    (<=*
                                                                     'in_c_val_rcvd
                                                                     'in_c_val_rcvd))
                                                                   (list
                                                                    (if*
                                                                     (and*
                                                                      (and*
                                                                       (lt*
                                                                        (bv #x0000001f 32)
                                                                        'in_c_bal_rcvd)
                                                                       (and*
                                                                        (bweq*
                                                                         'phase
                                                                         (bv #x00000007 32))
                                                                        (eq*
                                                                         #f
                                                                         (lt*
                                                                          (bv #x0000001f 32)
                                                                          'in_c_val_rcvd))))
                                                                      (or*
                                                                       (and*
                                                                        (not*
                                                                         'd16)
                                                                        'd15)
                                                                       (and*
                                                                        (not*
                                                                         'd15)
                                                                        'd16)))
                                                                     (list
                                                                      (<=*
                                                                       'd16
                                                                       'd15)
                                                                      (<=*
                                                                       'in_c_bal_vals
                                                                       'in_c_bal_vals)
                                                                      (<=*
                                                                       'in_c_bal_rcvd
                                                                       'in_c_bal_rcvd)
                                                                      (<=*
                                                                       'in_c_val_vals
                                                                       (bwxor*
                                                                        (bwnot*
                                                                         (shl*
                                                                          (bool->vect*
                                                                           'd17)
                                                                          'in_c_val_rcvd))
                                                                        (bwor*
                                                                         (bwnot*
                                                                          'in_c_val_vals)
                                                                         (shl*
                                                                          (bv #x00000001 32)
                                                                          'in_c_val_rcvd))))
                                                                      (<=*
                                                                       'in_c_val_rcvd
                                                                       (add*
                                                                        (bv #x00000001 32)
                                                                        'in_c_val_rcvd)))
                                                                     (list
                                                                      (if*
                                                                       (and*
                                                                        (and*
                                                                         (lt*
                                                                          (bv #x0000001f 32)
                                                                          'in_b_val_rcvd)
                                                                         (and*
                                                                          (lt*
                                                                           (bv #x0000001f 32)
                                                                           'in_c_val_rcvd)
                                                                          (bweq*
                                                                           'phase
                                                                           (bv #x00000007 32))))
                                                                        (lt*
                                                                         (bv #x0000001f 32)
                                                                         'in_a_val_rcvd))
                                                                       (list
                                                                        (<=*
                                                                         'a_mbal
                                                                         'in_a_bal_vals)
                                                                        (<=*
                                                                         'b_mbal
                                                                         'in_b_bal_vals)
                                                                        (<=*
                                                                         'c_mbal
                                                                         'in_c_bal_vals)
                                                                        (<=*
                                                                         'a_mval
                                                                         'in_a_val_vals)
                                                                        (<=*
                                                                         'b_mval
                                                                         'in_b_val_vals)
                                                                        (<=*
                                                                         'c_mval
                                                                         'in_c_val_vals)
                                                                        (<=*
                                                                         'phase
                                                                         (bv #x00000008 32)))
                                                                       (list
                                                                        (if*
                                                                         (and*
                                                                          (bweq*
                                                                           'value
                                                                           'a_mval)
                                                                          (and*
                                                                           (bweq*
                                                                            'value
                                                                            'b_mval)
                                                                           (and*
                                                                            (bweq*
                                                                             'phase
                                                                             (bv #x00000008 32))
                                                                            (bweq*
                                                                             'value
                                                                             'c_mval))))
                                                                         (list
                                                                          (<=*
                                                                           'phase
                                                                           (bv #x00000000 32)))
                                                                         (list
                                                                          (if*
                                                                           (bweq*
                                                                            (bv #x00000008 32)
                                                                            'phase)
                                                                           (list
                                                                            (<=*
                                                                             'phase
                                                                             (bv #x000000ff 32)))
                                                                           '()))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

;; cpu time: 101239 real time: 3414116 gc time: 6151
(define acceptor-impl
  (verilog-module*
   'acceptor
   '(d3 d4 d5 d0 d1 d2 clock reset)
   (list
    (reg* 32 'in_prop_val_rcvd)
    (reg* 32 'in_prop_val_vals)
    (reg* 32 'in_prop_bal_rcvd)
    (reg* 32 'in_prop_bal_vals)
    (reg* 32 'out_prop_val_sent)
    (reg* 32 'out_prop_val_vals)
    (reg* 32 'out_prop_bal_sent)
    (reg* 32 'out_prop_bal_vals)
    (input* (wire* 1 'd3))
    (output* (reg* 1 'd4))
    (input* (wire* 1 'd5))
    (output* (reg* 1 'd0))
    (input* (wire* 1 'd1))
    (output* (reg* 1 'd2))
    (reg* 32 'prop_mval)
    (reg* 32 'prop_mbal)
    (reg* 32 'prom_bal)
    (reg* 32 'phase)
    (reg* 32 'value)
    (reg* 32 'ballot)
    (input* (wire* 1 'clock))
    (input* (wire* 1 'reset)))
   (list
    (always*
     (or* (posedge* 'clock) (posedge* 'reset))
     (list
      (if*
       'reset
       (list
        (<=* 'ballot (bv #x00000000 32))
        (<=* 'value (bv #x00000000 32))
        (<=* 'phase (bv #x00000001 32))
        (<=* 'prom_bal (bv #x00000000 32))
        (<=* 'in_prop_bal_vals (bv #x00000000 32))
        (<=* 'in_prop_bal_rcvd (bv #x00000000 32)))
       (list
        (if*
         (bweq* (bv #x00000001 32) 'phase)
         (list
          (<=* 'in_prop_bal_vals (bv #x00000000 32))
          (<=* 'in_prop_bal_rcvd (bv #x00000000 32))
          (<=* 'phase (bv #x00000002 32)))
         (list
          (if*
           (and*
            (or* (and* 'd3 (eq* 'd4 #f)) (and* 'd4 (not* 'd3)))
            (and*
             (not* (lt* (bv #x0000001f 32) 'in_prop_bal_rcvd))
             (bweq* 'phase (bv #x00000002 32))))
           (list
            (<=* 'd4 'd3)
            (<=*
             'in_prop_bal_vals
             (bwxor*
              (bwnot* (shl* (bool->vect* 'd5) 'in_prop_bal_rcvd))
              (bwor*
               (bwnot* 'in_prop_bal_vals)
               (shl* (bv #x00000001 32) 'in_prop_bal_rcvd))))
            (<=* 'in_prop_bal_rcvd (add* 'in_prop_bal_rcvd (bv #x00000001 32))))
           (list
            (if*
             (and*
              (bweq* (bv #x00000002 32) 'phase)
              (lt* (bv #x0000001f 32) 'in_prop_bal_rcvd))
             (list
              (<=* 'prop_mbal 'in_prop_bal_vals)
              (<=* 'phase (bv #x00000003 32)))
             (list
              (if*
               (and*
                (and*
                 (lt* 'prom_bal 'prop_mbal)
                 (bweq* (bv #x00000003 32) 'phase))
                (lt* 'ballot 'prop_mbal))
               (list
                (<=* 'out_prop_bal_vals 'ballot)
                (<=* 'out_prop_bal_sent (bv #x00000000 32))
                (<=* 'out_prop_val_vals 'value)
                (<=* 'out_prop_val_sent (bv #x00000000 32))
                (<=* 'prom_bal 'prop_mbal)
                (<=* 'phase (bv #x00000004 32)))
               (list
                (if*
                 (and*
                  (not* (or* (and* (not* 'd0) 'd1) (and* 'd0 (eq* #f 'd1))))
                  (and*
                   (bweq* 'phase (bv #x00000004 32))
                   (not* (lt* (bv #x0000001f 32) 'out_prop_bal_sent))))
                 (list
                  (<=*
                   'd2
                   (lt*
                    (bwxor*
                     'out_prop_bal_vals
                     (shl* (bv #x00000001 32) 'out_prop_bal_sent))
                    'out_prop_bal_vals))
                  (<=* 'd0 (not* 'd0))
                  (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                  (<=*
                   'out_prop_bal_sent
                   (add* 'out_prop_bal_sent (bv #x00000001 32)))
                  (<=* 'out_prop_val_vals 'out_prop_val_vals)
                  (<=* 'out_prop_val_sent 'out_prop_val_sent))
                 (list
                  (if*
                   (and*
                    (and*
                     (lt* (bv #x0000001f 32) 'out_prop_bal_sent)
                     (and*
                      (bweq* (bv #x00000004 32) 'phase)
                      (not* (lt* (bv #x0000001f 32) 'out_prop_val_sent))))
                    (not* (or* (and* (not* 'd1) 'd0) (and* (eq* 'd0 #f) 'd1))))
                   (list
                    (<=*
                     'd2
                     (lt*
                      (bwxor*
                       'out_prop_val_vals
                       (shl* (bv #x00000001 32) 'out_prop_val_sent))
                      (bwor* 'out_prop_val_vals (bv #x00000001 32))))
                    (<=* 'd0 (not* 'd1))
                    (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                    (<=* 'out_prop_bal_sent 'out_prop_bal_sent)
                    (<=* 'out_prop_val_vals 'out_prop_val_vals)
                    (<=*
                     'out_prop_val_sent
                     (add* 'out_prop_val_sent (bv #x00000001 32))))
                   (list
                    (if*
                     (and*
                      (bweq* (bv #x00000004 32) 'phase)
                      (lt* (bv #x0000001f 32) 'out_prop_val_sent))
                     (list
                      (<=* 'in_prop_bal_vals (bv #x00000000 32))
                      (<=* 'in_prop_bal_rcvd (bv #x00000000 32))
                      (<=* 'in_prop_val_vals (bv #x00000000 32))
                      (<=* 'in_prop_val_rcvd (bv #x00000000 32))
                      (<=* 'phase (bv #x00000005 32)))
                     (list
                      (if*
                       (and*
                        (and*
                         (not* (lt* (bv #x0000001f 32) 'in_prop_bal_rcvd))
                         (bweq* (bv #x00000005 32) 'phase))
                        (or* (and* (not* 'd3) 'd4) (and* (not* 'd4) 'd3)))
                       (list
                        (<=* 'd4 'd3)
                        (<=*
                         'in_prop_bal_vals
                         (bwxor*
                          (bwnot* (shl* (bool->vect* 'd5) 'in_prop_bal_rcvd))
                          (bwor*
                           (shl* (bv #x00000001 32) 'in_prop_bal_rcvd)
                           (bwxor* 'in_prop_bal_vals (bv #xffffffff 32)))))
                        (<=*
                         'in_prop_bal_rcvd
                         (add* 'in_prop_bal_rcvd (bv #x00000001 32)))
                        (<=* 'in_prop_val_vals 'in_prop_val_vals)
                        (<=* 'in_prop_val_rcvd 'in_prop_val_rcvd))
                       (list
                        (if*
                         (and*
                          (and*
                           (and*
                            (bweq* 'phase (bv #x00000005 32))
                            (not* (lt* (bv #x0000001f 32) 'in_prop_val_rcvd)))
                           (lt* (bv #x0000001f 32) 'in_prop_bal_rcvd))
                          (or* (and* (eq* #f 'd3) 'd4) (and* (not* 'd4) 'd3)))
                         (list
                          (<=* 'd4 'd3)
                          (<=* 'in_prop_bal_vals 'in_prop_bal_vals)
                          (<=* 'in_prop_bal_rcvd 'in_prop_bal_rcvd)
                          (<=*
                           'in_prop_val_vals
                           (bwxor*
                            (bwor*
                             (bwnot* 'in_prop_val_vals)
                             (shl* (bv #x00000001 32) 'in_prop_val_rcvd))
                            (bwnot* (shl* (bool->vect* 'd5) 'in_prop_val_rcvd))))
                          (<=*
                           'in_prop_val_rcvd
                           (add* (bv #x00000001 32) 'in_prop_val_rcvd)))
                         (list
                          (if*
                           (and*
                            (bweq* (bv #x00000005 32) 'phase)
                            (lt* (bv #x0000001f 32) 'in_prop_val_rcvd))
                           (list
                            (<=* 'prop_mbal 'in_prop_bal_vals)
                            (<=* 'prop_mval 'in_prop_val_vals)
                            (<=* 'phase (bv #x00000006 32)))
                           (list
                            (if*
                             (and*
                              (bweq* 'prop_mbal 'prom_bal)
                              (bweq* 'phase (bv #x00000006 32)))
                             (list
                              (<=* 'ballot 'prom_bal)
                              (<=* 'value 'prop_mval)
                              (<=* 'out_prop_bal_vals 'prom_bal)
                              (<=* 'out_prop_bal_sent (bv #x00000000 32))
                              (<=* 'out_prop_val_vals 'prop_mval)
                              (<=* 'out_prop_val_sent (bv #x00000000 32))
                              (<=* 'phase (bv #x00000007 32)))
                             (list
                              (if*
                               (and*
                                (and*
                                 (bweq* 'phase (bv #x00000007 32))
                                 (not*
                                  (lt* (bv #x0000001f 32) 'out_prop_bal_sent)))
                                (eq* 'd0 'd1))
                               (list
                                (<=*
                                 'd2
                                 (lt*
                                  (bwxor*
                                   (shl* (bv #x00000001 32) 'out_prop_bal_sent)
                                   'out_prop_bal_vals)
                                  'out_prop_bal_vals))
                                (<=* 'd0 (not* 'd0))
                                (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                                (<=*
                                 'out_prop_bal_sent
                                 (add* (bv #x00000001 32) 'out_prop_bal_sent))
                                (<=* 'out_prop_val_vals 'out_prop_val_vals)
                                (<=* 'out_prop_val_sent 'out_prop_val_sent))
                               (list
                                (if*
                                 (and*
                                  (not*
                                   (or*
                                    (and* (eq* #f 'd1) 'd0)
                                    (and* 'd1 (eq* #f 'd0))))
                                  (and*
                                   (lt* (bv #x0000001f 32) 'out_prop_bal_sent)
                                   (and*
                                    (bweq* (bv #x00000007 32) 'phase)
                                    (not*
                                     (lt*
                                      (bv #x0000001f 32)
                                      'out_prop_val_sent)))))
                                 (list
                                  (<=*
                                   'd2
                                   (lt*
                                    (bwxor*
                                     (shl* (bv #x00000001 32) 'out_prop_val_sent)
                                     'out_prop_val_vals)
                                    'out_prop_val_vals))
                                  (<=* 'd0 (not* 'd0))
                                  (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                                  (<=* 'out_prop_bal_sent 'out_prop_bal_sent)
                                  (<=* 'out_prop_val_vals 'out_prop_val_vals)
                                  (<=*
                                   'out_prop_val_sent
                                   (add* 'out_prop_val_sent (bv #x00000001 32))))
                                 (list
                                  (if*
                                   (and*
                                    (lt* (bv #x0000001f 32) 'out_prop_val_sent)
                                    (bweq* 'phase (bv #x00000007 32)))
                                   (list (<=* 'phase (bv #x00000000 32)))
                                   '()))))))))))))))))))))))))))))))))))

;; Before verilog expr inversion fix:
;; cpu time: 12854 real time: 1009093 gc time: 777
;; After expr inversion fix:
;; cpu time: 8795 real time: 448011 gc time: 1245
;; Final
;; cpu time: 5017 real time: 463056 gc time: 242

;; cpu time: 17 real time: 17 gc time: 0
;; cpu time: 368 real time: 1141680 gc time: 44
;; cpu time: 50 real time: 50 gc time: 36
;; cpu time: 296 real time: 741669 gc time: 14
;; (let* ([unity-prog proposer]
;;        [verilog-prog verilog-proposer])
;;   (list
;;    (time (verify-verilog-reset unity-prog verilog-prog))
;;    (time (verify-verilog-clock unity-prog verilog-prog))))

;; cpu time: 6 real time: 6 gc time: 0
;; cpu time: 177 real time: 3887415 gc time: 0
;; cpu time: 4 real time: 5 gc time: 0
;; cpu time: 100 real time: 3668276 gc time: 22
;; (let* ([unity-prog acceptor]
;;        [verilog-prog verilog-acceptor])
;;   (list
;;    (time (verify-verilog-reset unity-prog verilog-prog))
;;    (time (verify-verilog-clock unity-prog verilog-prog))))

;; (time
;;  (let* ([prog mini-test]
;;         [synthesized-module (unity-prog->verilog-module prog 'mini-test)])
;;    synthesized-module))

;; cpu time: 57375 real time: 4974033 gc time: 9814

;; current-bitwidth = 9
;; cpu time: 63782 real time: 1244176 gc time: 13701
;; flatten choose* tree for vectexp??
;; cpu time: 75682 real time: 2357191 gc time: 17017
;; back to normal
;; cpu time: 58104 real time: 1339199 gc time: 11067
;; 32-bit
;; cpu time: 101053 real time: 10041801 gc time: 13496
;; Memoization (variables, no subterms)
;; cpu time: 70291 real time: 3722464 gc time: 11201
;; cpu time: 89805 real time: 5485750 gc time: 14467
;; Rosette 4 Clean Term/VC, memoized with subterms
;; cpu time: 82098 real time: 1838726 gc time: 4997

;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)])
;;    synthesized-module))

;; (time
;;  (let* ([prog acceptor]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (synth-traces? (unity-prog->synth-traces prog synth-map))))

;; cpu time: 8227 real time: 3761960 gc time: 133
;; cpu time: 6009 real time: 2293251 gc time: 89
;; cpu time: 6094 real time: 985512 gc time: 120
;; cpu time: 8561 real time: 613846 gc time: 557
;; Rosette 4 Clean Term/VC
;; cpu time: 6662 real time: 1831100 gc time: 332

;; (time
;;  (let* ([prog mini-test])
;;    (unity-prog->verilog-module prog 'mini)))

;; (time
;;  (let* ([prog mini-test]
;;         [synth-map (unity-prog->synth-map prog)])
;;    (synth-traces? (unity-prog->synth-traces prog synth-map))))

;; (output-smt "/Users/cchen/Desktop/smt")
;; (time
;;  (let* ([prog mini-test]
;;         [synthesized-module (unity-prog->verilog-module prog 'mini)])
;;    synthesized-module))

;; cpu time: 965423 real time: 7357224 gc time: 587507
;; Fixed bitwidth
;; cpu time: 1920631 real time: 6468498 gc time: 1419084
;; Memoized 32-bit (variables, no subterms)
;; cpu time: 2050351 real time: 14786842 gc time: 1380073
;; Rosette 4 Clean Term/VC, memoized with subterms
;; cpu time: 1034988 real time: 7294801 gc time: 142711


(time
 (let* ([prog proposer]
        [synthesized-module (unity-prog->verilog-module prog 'proposer)])
   synthesized-module))

;; (time
;;  (let* ([prog mini-prop]
;;         [synthesized-module (unity-prog->verilog-module prog 'mini-prop)])
;;    synthesized-module))

;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)]
;;         [verifier-results (verify-verilog-module prog synthesized-module)])
;;    (if (verify-ok? verifier-results)
;;        (print-verilog-module synthesized-module)
;;        verifier-results)))
