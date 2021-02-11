#lang rosette/safe

(require "paxos.rkt"
         "verilog/backend.rkt"
         "verilog/syntax.rkt"
         "verilog/synth.rkt"
         "verilog/verify.rkt")

(define verilog-proposer2
  (verilog-module*
   'proposer
   '(d15 d16 d17 d12 d13 d14 d9 d10 d11 d6 d7 d8 d3 d4 d5 d0 d1 d2 clock reset)
   (list
    (reg* 8 'in_c_val_rcvd)
    (reg* 8 'in_c_val_vals)
    (reg* 8 'in_b_val_rcvd)
    (reg* 8 'in_b_val_vals)
    (reg* 8 'in_a_val_rcvd)
    (reg* 8 'in_a_val_vals)
    (reg* 8 'in_c_bal_rcvd)
    (reg* 8 'in_c_bal_vals)
    (reg* 8 'in_b_bal_rcvd)
    (reg* 8 'in_b_bal_vals)
    (reg* 8 'in_a_bal_rcvd)
    (reg* 8 'in_a_bal_vals)
    (reg* 8 'out_c_val_sent)
    (reg* 8 'out_c_val_vals)
    (reg* 8 'out_b_val_sent)
    (reg* 8 'out_b_val_vals)
    (reg* 8 'out_a_val_sent)
    (reg* 8 'out_a_val_vals)
    (reg* 8 'out_c_bal_sent)
    (reg* 8 'out_c_bal_vals)
    (reg* 8 'out_b_bal_sent)
    (reg* 8 'out_b_bal_vals)
    (reg* 8 'out_a_bal_sent)
    (reg* 8 'out_a_bal_vals)
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
    (reg* 8 'c_mval)
    (reg* 8 'b_mval)
    (reg* 8 'a_mval)
    (reg* 8 'c_mbal)
    (reg* 8 'b_mbal)
    (reg* 8 'a_mbal)
    (reg* 8 'phase)
    (reg* 8 'value)
    (reg* 8 'ballot)
    (input* (wire* 1 'clock))
    (input* (wire* 1 'reset)))
   (list
    (always*
     (or* (posedge* 'clock) (posedge* 'reset))
     (list
      (if*
       'reset
       (list
        (<=* 'phase (bv #x01 8))
        (<=* 'value (bv #x20 8))
        (<=* 'ballot (bv #x01 8)))
       (list
        (if*
         (bweq* 'ballot (bv #xff 8))
         (list (<=* 'phase (bv #xff 8)))
         (list
          (if*
           (bweq* (bv #x01 8) 'phase)
           (list
            (<=* 'phase (bv #x02 8))
            (<=* 'out_c_bal_vals 'ballot)
            (<=* 'out_c_bal_sent (bv #x00 8))
            (<=* 'out_b_bal_vals 'ballot)
            (<=* 'out_b_bal_sent (bv #x00 8))
            (<=* 'out_a_bal_vals 'ballot)
            (<=* 'out_a_bal_sent (bv #x00 8)))
           (list
            (if*
             (and*
              (and*
               (bweq* 'phase (bv #x02 8))
               (eq* #f (lt* (bv #x07 8) 'out_a_bal_sent)))
              (not* (or* (and* 'd0 (eq* #f 'd1)) (and* (eq* #f 'd0) 'd1))))
             (list
              (<=* 'out_a_bal_vals 'out_a_bal_vals)
              (<=* 'out_a_bal_sent (add* 'out_a_bal_sent (bv #x01 8)))
              (<=*
               'd2
               (eq*
                (eq*
                 (bv #x00 8)
                 (bwand* 'out_a_bal_vals (shl* (bv #x01 8) 'out_a_bal_sent)))
                #f))
              (<=* 'd0 (eq* 'd1 #f)))
             (list
              (if*
               (and*
                (and*
                 (eq* #f (lt* (bv #x07 8) 'out_b_bal_sent))
                 (bweq* 'phase (bv #x02 8)))
                (eq* 'd4 'd3))
               (list
                (<=* 'out_b_bal_vals 'out_b_bal_vals)
                (<=* 'out_b_bal_sent (add* 'out_b_bal_sent (bv #x01 8)))
                (<=*
                 'd5
                 (eq*
                  (bv #xff 8)
                  (bwor* (bv #xfe 8) (shr* 'out_b_bal_vals 'out_b_bal_sent))))
                (<=* 'd3 (eq* 'd4 #f)))
               (list
                (if*
                 (and*
                  (and*
                   (bweq* (bv #x02 8) 'phase)
                   (eq* #f (lt* (bv #x07 8) 'out_c_bal_sent)))
                  (not* (or* (and* 'd6 (not* 'd7)) (and* (eq* #f 'd6) 'd7))))
                 (list
                  (<=* 'out_c_bal_vals 'out_c_bal_vals)
                  (<=* 'out_c_bal_sent (add* 'out_c_bal_sent (bv #x01 8)))
                  (<=*
                   'd8
                   (eq*
                    (bwand*
                     (bwnot* 'out_c_bal_vals)
                     (shl* (bv #x01 8) 'out_c_bal_sent))
                    (bv #x00 8)))
                  (<=* 'd6 (not* 'd7)))
                 (list
                  (if*
                   (and*
                    (and*
                     (lt* (bv #x07 8) 'out_b_bal_sent)
                     (and*
                      (bweq* 'phase (bv #x02 8))
                      (lt* (bv #x07 8) 'out_c_bal_sent)))
                    (lt* (bv #x07 8) 'out_a_bal_sent))
                   (list
                    (<=* 'phase (bv #x03 8))
                    (<=* 'in_c_val_vals (bv #x00 8))
                    (<=* 'in_c_val_rcvd (bv #x00 8))
                    (<=* 'in_b_val_vals (bv #x00 8))
                    (<=* 'in_b_val_rcvd (bv #x00 8))
                    (<=* 'in_a_val_vals (bv #x00 8))
                    (<=* 'in_a_val_rcvd (bv #x00 8))
                    (<=* 'in_c_bal_vals (bv #x00 8))
                    (<=* 'in_c_bal_rcvd (bv #x00 8))
                    (<=* 'in_b_bal_vals (bv #x00 8))
                    (<=* 'in_b_bal_rcvd (bv #x00 8))
                    (<=* 'in_a_bal_vals (bv #x00 8))
                    (<=* 'in_a_bal_rcvd (bv #x00 8)))
                   (list
                    (if*
                     (and*
                      (and*
                       (bweq* 'phase (bv #x03 8))
                       (eq* #f (lt* (bv #x07 8) 'in_a_bal_rcvd)))
                      (or* (and* 'd9 (not* 'd10)) (and* 'd10 (eq* 'd9 #f))))
                     (list
                      (<=* 'in_a_val_vals 'in_a_val_vals)
                      (<=* 'in_a_val_rcvd 'in_a_val_rcvd)
                      (<=*
                       'in_a_bal_vals
                       (bwxor*
                        (shl*
                         (bwxor* (bool->vect* 'd11) (bv #x01 8))
                         'in_a_bal_rcvd)
                        (bwor*
                         'in_a_bal_vals
                         (shl* (bv #x01 8) 'in_a_bal_rcvd))))
                      (<=* 'in_a_bal_rcvd (add* (bv #x01 8) 'in_a_bal_rcvd))
                      (<=* 'd10 'd9))
                     (list
                      (if*
                       (and*
                        (and*
                         (lt* (bv #x07 8) 'in_a_bal_rcvd)
                         (and*
                          (lt* 'in_a_val_rcvd (bv #x08 8))
                          (bweq* (bv #x03 8) 'phase)))
                        (or* (and* 'd9 (eq* #f 'd10)) (and* (eq* 'd9 #f) 'd10)))
                       (list
                        (<=*
                         'in_a_val_vals
                         (bwxor*
                          (bwxor*
                           (shl* (bool->vect* 'd11) 'in_a_val_rcvd)
                           (bv #xff 8))
                          (bwor*
                           (shl* (bv #x01 8) 'in_a_val_rcvd)
                           (bwnot* 'in_a_val_vals))))
                        (<=* 'in_a_val_rcvd (add* 'in_a_val_rcvd (bv #x01 8)))
                        (<=* 'in_a_bal_vals 'in_a_bal_vals)
                        (<=* 'in_a_bal_rcvd 'in_a_bal_rcvd)
                        (<=* 'd10 'd9))
                       (list
                        (if*
                         (and*
                          (or* (and* (not* 'd12) 'd13) (and* (not* 'd13) 'd12))
                          (and*
                           (bweq* (bv #x03 8) 'phase)
                           (eq* #f (lt* (bv #x07 8) 'in_b_bal_rcvd))))
                         (list
                          (<=* 'in_b_val_vals 'in_b_val_vals)
                          (<=* 'in_b_val_rcvd 'in_b_val_rcvd)
                          (<=*
                           'in_b_bal_vals
                           (bwxor*
                            (bwor*
                             (shl* (bv #x01 8) 'in_b_bal_rcvd)
                             (bwnot* 'in_b_bal_vals))
                            (bwxor*
                             (shl* (bool->vect* 'd14) 'in_b_bal_rcvd)
                             (bv #xff 8))))
                          (<=* 'in_b_bal_rcvd (add* 'in_b_bal_rcvd (bv #x01 8)))
                          (<=* 'd13 'd12))
                         (list
                          (if*
                           (and*
                            (and*
                             (and*
                              (eq* #f (lt* (bv #x07 8) 'in_b_val_rcvd))
                              (bweq* (bv #x03 8) 'phase))
                             (lt* (bv #x07 8) 'in_b_bal_rcvd))
                            (or*
                             (and* 'd13 (eq* 'd12 #f))
                             (and* 'd12 (eq* 'd13 #f))))
                           (list
                            (<=*
                             'in_b_val_vals
                             (bwxor*
                              (bwnot* (shl* (bool->vect* 'd14) 'in_b_val_rcvd))
                              (bwor*
                               (shl* (bv #x01 8) 'in_b_val_rcvd)
                               (bwnot* 'in_b_val_vals))))
                            (<=*
                             'in_b_val_rcvd
                             (add* (bv #x01 8) 'in_b_val_rcvd))
                            (<=* 'in_b_bal_vals 'in_b_bal_vals)
                            (<=* 'in_b_bal_rcvd 'in_b_bal_rcvd)
                            (<=* 'd13 'd12))
                           (list
                            (if*
                             (and*
                              (or*
                               (and* 'd16 (not* 'd15))
                               (and* (eq* 'd16 #f) 'd15))
                              (and*
                               (bweq* (bv #x03 8) 'phase)
                               (eq* #f (lt* (bv #x07 8) 'in_c_bal_rcvd))))
                             (list
                              (<=* 'in_c_val_vals 'in_c_val_vals)
                              (<=* 'in_c_val_rcvd 'in_c_val_rcvd)
                              (<=*
                               'in_c_bal_vals
                               (bwxor*
                                (bwor*
                                 (shl* (bv #x01 8) 'in_c_bal_rcvd)
                                 'in_c_bal_vals)
                                (shl*
                                 (bwxor* (bv #x01 8) (bool->vect* 'd17))
                                 'in_c_bal_rcvd)))
                              (<=*
                               'in_c_bal_rcvd
                               (add* (bv #x01 8) 'in_c_bal_rcvd))
                              (<=* 'd16 'd15))
                             (list
                              (if*
                               (and*
                                (or*
                                 (and* 'd15 (not* 'd16))
                                 (and* 'd16 (not* 'd15)))
                                (and*
                                 (lt* (bv #x07 8) 'in_c_bal_rcvd)
                                 (and*
                                  (eq* #f (lt* (bv #x07 8) 'in_c_val_rcvd))
                                  (bweq* 'phase (bv #x03 8)))))
                               (list
                                (<=*
                                 'in_c_val_vals
                                 (bwxor*
                                  (bwand*
                                   'in_c_val_vals
                                   (shl* (bv #x01 8) 'in_c_val_rcvd))
                                  (bwxor*
                                   'in_c_val_vals
                                   (shl* (bool->vect* 'd17) 'in_c_val_rcvd))))
                                (<=*
                                 'in_c_val_rcvd
                                 (add* (bv #x01 8) 'in_c_val_rcvd))
                                (<=* 'in_c_bal_vals 'in_c_bal_vals)
                                (<=* 'in_c_bal_rcvd 'in_c_bal_rcvd)
                                (<=* 'd16 'd15))
                               (list
                                (if*
                                 (and*
                                  (lt* (bv #x07 8) 'in_a_val_rcvd)
                                  (and*
                                   (lt* (bv #x07 8) 'in_b_val_rcvd)
                                   (and*
                                    (bweq* (bv #x03 8) 'phase)
                                    (lt* (bv #x07 8) 'in_c_val_rcvd))))
                                 (list
                                  (<=* 'phase (bv #x04 8))
                                  (<=* 'c_mval 'in_c_val_vals)
                                  (<=* 'b_mval 'in_b_val_vals)
                                  (<=* 'a_mval 'in_a_val_vals)
                                  (<=* 'c_mbal 'in_c_bal_vals)
                                  (<=* 'b_mbal 'in_b_bal_vals)
                                  (<=* 'a_mbal 'in_a_bal_vals))
                                 (list
                                  (if*
                                   (and*
                                    (and*
                                     (and*
                                      (bweq* 'phase (bv #x04 8))
                                      (bweq* (bv #x00 8) 'c_mbal))
                                     (bweq* 'b_mbal (bv #x00 8)))
                                    (lt* 'a_mbal (bv #x01 8)))
                                   (list
                                    (<=* 'phase (bv #x05 8))
                                    (<=* 'value 'value))
                                   (list
                                    (if*
                                     (and*
                                      (or*
                                       (lt* 'b_mbal 'a_mbal)
                                       (bweq* 'b_mbal 'a_mbal))
                                      (and*
                                       (or*
                                        (bweq* 'a_mbal 'c_mbal)
                                        (lt* 'c_mbal 'a_mbal))
                                       (bweq* (bv #x04 8) 'phase)))
                                     (list
                                      (<=* 'phase (bv #x05 8))
                                      (<=* 'value 'a_mval))
                                     (list
                                      (if*
                                       (and*
                                        (bweq* (bv #x04 8) 'phase)
                                        (or*
                                         (bweq* 'b_mbal 'c_mbal)
                                         (lt* 'c_mbal 'b_mbal)))
                                       (list
                                        (<=* 'phase (bv #x05 8))
                                        (<=* 'value 'b_mval))
                                       (list
                                        (if*
                                         (bweq* (bv #x04 8) 'phase)
                                         (list
                                          (<=* 'phase (bv #x05 8))
                                          (<=* 'value 'c_mval))
                                         (list
                                          (if*
                                           (bweq* (bv #x05 8) 'phase)
                                           (list
                                            (<=* 'phase (bv #x06 8))
                                            (<=* 'out_c_val_vals 'value)
                                            (<=* 'out_c_val_sent (bv #x00 8))
                                            (<=* 'out_b_val_vals 'value)
                                            (<=* 'out_b_val_sent (bv #x00 8))
                                            (<=* 'out_a_val_vals 'value)
                                            (<=* 'out_a_val_sent (bv #x00 8))
                                            (<=* 'out_c_bal_vals 'ballot)
                                            (<=* 'out_c_bal_sent (bv #x00 8))
                                            (<=* 'out_b_bal_vals 'ballot)
                                            (<=* 'out_b_bal_sent (bv #x00 8))
                                            (<=* 'out_a_bal_vals 'ballot)
                                            (<=* 'out_a_bal_sent (bv #x00 8)))
                                           (list
                                            (if*
                                             (and*
                                              (eq* 'd1 'd0)
                                              (and*
                                               (bweq* 'phase (bv #x06 8))
                                               (not*
                                                (lt*
                                                 (bv #x07 8)
                                                 'out_a_bal_sent))))
                                             (list
                                              (<=*
                                               'out_a_val_vals
                                               'out_a_val_vals)
                                              (<=*
                                               'out_a_val_sent
                                               'out_a_val_sent)
                                              (<=*
                                               'out_a_bal_vals
                                               'out_a_bal_vals)
                                              (<=*
                                               'out_a_bal_sent
                                               (add*
                                                'out_a_bal_sent
                                                (bv #x01 8)))
                                              (<=*
                                               'd2
                                               (lt*
                                                (bwand*
                                                 (shl*
                                                  (bv #x01 8)
                                                  'out_a_bal_sent)
                                                 (bwnot* 'out_a_bal_vals))
                                                (bv #x01 8)))
                                              (<=* 'd0 (eq* 'd1 #f)))
                                             (list
                                              (if*
                                               (and*
                                                (and*
                                                 (lt*
                                                  (bv #x07 8)
                                                  'out_a_bal_sent)
                                                 (and*
                                                  (bweq* 'phase (bv #x06 8))
                                                  (not*
                                                   (lt*
                                                    (bv #x07 8)
                                                    'out_a_val_sent))))
                                                (eq* 'd1 'd0))
                                               (list
                                                (<=*
                                                 'out_a_val_vals
                                                 'out_a_val_vals)
                                                (<=*
                                                 'out_a_val_sent
                                                 (add*
                                                  'out_a_val_sent
                                                  (bv #x01 8)))
                                                (<=*
                                                 'out_a_bal_vals
                                                 'out_a_bal_vals)
                                                (<=*
                                                 'out_a_bal_sent
                                                 'out_a_bal_sent)
                                                (<=*
                                                 'd2
                                                 (bweq*
                                                  (bwand*
                                                   (shr*
                                                    'out_a_val_vals
                                                    'out_a_val_sent)
                                                   (bv #x01 8))
                                                  (bv #x01 8)))
                                                (<=* 'd0 (eq* 'd1 #f)))
                                               (list
                                                (if*
                                                 (and*
                                                  (not*
                                                   (or*
                                                    (and* (eq* #f 'd4) 'd3)
                                                    (and* 'd4 (eq* 'd3 #f))))
                                                  (and*
                                                   (bweq* 'phase (bv #x06 8))
                                                   (eq*
                                                    (lt*
                                                     (bv #x07 8)
                                                     'out_b_bal_sent)
                                                    #f)))
                                                 (list
                                                  (<=*
                                                   'out_b_val_vals
                                                   'out_b_val_vals)
                                                  (<=*
                                                   'out_b_val_sent
                                                   'out_b_val_sent)
                                                  (<=*
                                                   'out_b_bal_vals
                                                   'out_b_bal_vals)
                                                  (<=*
                                                   'out_b_bal_sent
                                                   (add*
                                                    'out_b_bal_sent
                                                    (bv #x01 8)))
                                                  (<=*
                                                   'd5
                                                   (eq*
                                                    (bwand*
                                                     (bwnot* 'out_b_bal_vals)
                                                     (shl*
                                                      (bv #x01 8)
                                                      'out_b_bal_sent))
                                                    (bv #x00 8)))
                                                  (<=* 'd3 (not* 'd3)))
                                                 (list
                                                  (if*
                                                   (and*
                                                    (and*
                                                     (lt*
                                                      (bv #x07 8)
                                                      'out_b_bal_sent)
                                                     (and*
                                                      (lt*
                                                       'out_b_val_sent
                                                       (bv #x08 8))
                                                      (bweq*
                                                       'phase
                                                       (bv #x06 8))))
                                                    (not*
                                                     (or*
                                                      (and* (not* 'd3) 'd4)
                                                      (and* 'd3 (eq* 'd4 #f)))))
                                                   (list
                                                    (<=*
                                                     'out_b_val_vals
                                                     'out_b_val_vals)
                                                    (<=*
                                                     'out_b_val_sent
                                                     (add*
                                                      'out_b_val_sent
                                                      (bv #x01 8)))
                                                    (<=*
                                                     'out_b_bal_vals
                                                     'out_b_bal_vals)
                                                    (<=*
                                                     'out_b_bal_sent
                                                     'out_b_bal_sent)
                                                    (<=*
                                                     'd5
                                                     (not*
                                                      (bweq*
                                                       (bv #x00 8)
                                                       (bwand*
                                                        (shr*
                                                         'out_b_val_vals
                                                         'out_b_val_sent)
                                                        (bv #x01 8)))))
                                                    (<=* 'd3 (not* 'd4)))
                                                   (list
                                                    (if*
                                                     (and*
                                                      (and*
                                                       (bweq* 'phase (bv #x06 8))
                                                       (not*
                                                        (lt*
                                                         (bv #x07 8)
                                                         'out_c_bal_sent)))
                                                      (eq* 'd6 'd7))
                                                     (list
                                                      (<=*
                                                       'out_c_val_vals
                                                       'out_c_val_vals)
                                                      (<=*
                                                       'out_c_val_sent
                                                       'out_c_val_sent)
                                                      (<=*
                                                       'out_c_bal_vals
                                                       'out_c_bal_vals)
                                                      (<=*
                                                       'out_c_bal_sent
                                                       (add*
                                                        (bv #x01 8)
                                                        'out_c_bal_sent))
                                                      (<=*
                                                       'd8
                                                       (bweq*
                                                        (bwand*
                                                         (shl*
                                                          (bv #x01 8)
                                                          'out_c_bal_sent)
                                                         (bwxor*
                                                          (bv #xff 8)
                                                          'out_c_bal_vals))
                                                        (bv #x00 8)))
                                                      (<=* 'd6 (not* 'd6)))
                                                     (list
                                                      (if*
                                                       (and*
                                                        (and*
                                                         (and*
                                                          (bweq*
                                                           (bv #x06 8)
                                                           'phase)
                                                          (eq*
                                                           #f
                                                           (lt*
                                                            (bv #x07 8)
                                                            'out_c_val_sent)))
                                                         (lt*
                                                          (bv #x07 8)
                                                          'out_c_bal_sent))
                                                        (eq* 'd6 'd7))
                                                       (list
                                                        (<=*
                                                         'out_c_val_vals
                                                         'out_c_val_vals)
                                                        (<=*
                                                         'out_c_val_sent
                                                         (add*
                                                          (bv #x01 8)
                                                          'out_c_val_sent))
                                                        (<=*
                                                         'out_c_bal_vals
                                                         'out_c_bal_vals)
                                                        (<=*
                                                         'out_c_bal_sent
                                                         'out_c_bal_sent)
                                                        (<=*
                                                         'd8
                                                         (eq*
                                                          (bwor*
                                                           (shr*
                                                            'out_c_val_vals
                                                            'out_c_val_sent)
                                                           (bv #x01 8))
                                                          (shr*
                                                           'out_c_val_vals
                                                           'out_c_val_sent)))
                                                        (<=* 'd6 (eq* 'd7 #f)))
                                                       (list
                                                        (if*
                                                         (and*
                                                          (and*
                                                           (and*
                                                            (bweq*
                                                             (bv #x06 8)
                                                             'phase)
                                                            (lt*
                                                             (bv #x07 8)
                                                             'out_c_val_sent))
                                                           (lt*
                                                            (bv #x07 8)
                                                            'out_b_val_sent))
                                                          (lt*
                                                           (bv #x07 8)
                                                           'out_a_val_sent))
                                                         (list
                                                          (<=*
                                                           'phase
                                                           (bv #x07 8))
                                                          (<=*
                                                           'in_c_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_bal_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_bal_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_bal_rcvd
                                                           (bv #x00 8)))
                                                         (list
                                                          (if*
                                                           (and*
                                                            (or*
                                                             (and*
                                                              (eq* #f 'd9)
                                                              'd10)
                                                             (and*
                                                              (eq* 'd10 #f)
                                                              'd9))
                                                            (and*
                                                             (bweq*
                                                              (bv #x07 8)
                                                              'phase)
                                                             (eq*
                                                              #f
                                                              (lt*
                                                               (bv #x07 8)
                                                               'in_a_bal_rcvd))))
                                                           (list
                                                            (<=*
                                                             'in_a_val_vals
                                                             'in_a_val_vals)
                                                            (<=*
                                                             'in_a_val_rcvd
                                                             'in_a_val_rcvd)
                                                            (<=*
                                                             'in_a_bal_vals
                                                             (bwxor*
                                                              (shl*
                                                               (shr*
                                                                (bv #x01 8)
                                                                (bool->vect*
                                                                 'd11))
                                                               'in_a_bal_rcvd)
                                                              (bwor*
                                                               (shl*
                                                                (bv #x01 8)
                                                                'in_a_bal_rcvd)
                                                               'in_a_bal_vals)))
                                                            (<=*
                                                             'in_a_bal_rcvd
                                                             (add*
                                                              'in_a_bal_rcvd
                                                              (bv #x01 8)))
                                                            (<=* 'd10 'd9))
                                                           (list
                                                            (if*
                                                             (and*
                                                              (and*
                                                               (and*
                                                                (not*
                                                                 (lt*
                                                                  (bv #x07 8)
                                                                  'in_a_val_rcvd))
                                                                (bweq*
                                                                 'phase
                                                                 (bv #x07 8)))
                                                               (lt*
                                                                (bv #x07 8)
                                                                'in_a_bal_rcvd))
                                                              (or*
                                                               (and*
                                                                'd10
                                                                (not* 'd9))
                                                               (and*
                                                                (not* 'd10)
                                                                'd9)))
                                                             (list
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
                                                                  (bv #x01 8)
                                                                  'in_a_val_rcvd)
                                                                 (bwnot*
                                                                  'in_a_val_vals))))
                                                              (<=*
                                                               'in_a_val_rcvd
                                                               (add*
                                                                (bv #x01 8)
                                                                'in_a_val_rcvd))
                                                              (<=*
                                                               'in_a_bal_vals
                                                               'in_a_bal_vals)
                                                              (<=*
                                                               'in_a_bal_rcvd
                                                               'in_a_bal_rcvd)
                                                              (<=* 'd10 'd9))
                                                             (list
                                                              (if*
                                                               (and*
                                                                (and*
                                                                 (eq*
                                                                  #f
                                                                  (lt*
                                                                   (bv #x07 8)
                                                                   'in_b_bal_rcvd))
                                                                 (bweq*
                                                                  (bv #x07 8)
                                                                  'phase))
                                                                (or*
                                                                 (and*
                                                                  'd12
                                                                  (eq* 'd13 #f))
                                                                 (and*
                                                                  'd13
                                                                  (eq*
                                                                   'd12
                                                                   #f))))
                                                               (list
                                                                (<=*
                                                                 'in_b_val_vals
                                                                 'in_b_val_vals)
                                                                (<=*
                                                                 'in_b_val_rcvd
                                                                 'in_b_val_rcvd)
                                                                (<=*
                                                                 'in_b_bal_vals
                                                                 (bwxor*
                                                                  (bwxor*
                                                                   (bv #xff 8)
                                                                   (shl*
                                                                    (bool->vect*
                                                                     'd14)
                                                                    'in_b_bal_rcvd))
                                                                  (bwor*
                                                                   (shl*
                                                                    (bv #x01 8)
                                                                    'in_b_bal_rcvd)
                                                                   (bwnot*
                                                                    'in_b_bal_vals))))
                                                                (<=*
                                                                 'in_b_bal_rcvd
                                                                 (add*
                                                                  (bv #x01 8)
                                                                  'in_b_bal_rcvd))
                                                                (<=* 'd13 'd12))
                                                               (list
                                                                (if*
                                                                 (and*
                                                                  (and*
                                                                   (and*
                                                                    (bweq*
                                                                     (bv #x07 8)
                                                                     'phase)
                                                                    (eq*
                                                                     #f
                                                                     (lt*
                                                                      (bv #x07 8)
                                                                      'in_b_val_rcvd)))
                                                                   (lt*
                                                                    (bv #x07 8)
                                                                    'in_b_bal_rcvd))
                                                                  (or*
                                                                   (and*
                                                                    'd12
                                                                    (eq*
                                                                     #f
                                                                     'd13))
                                                                   (and*
                                                                    (eq* #f 'd12)
                                                                    'd13)))
                                                                 (list
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
                                                                      (bv #x01 8)
                                                                      'in_b_val_rcvd)
                                                                     (bwxor*
                                                                      'in_b_val_vals
                                                                      (bv #xff 8)))))
                                                                  (<=*
                                                                   'in_b_val_rcvd
                                                                   (add*
                                                                    (bv #x01 8)
                                                                    'in_b_val_rcvd))
                                                                  (<=*
                                                                   'in_b_bal_vals
                                                                   'in_b_bal_vals)
                                                                  (<=*
                                                                   'in_b_bal_rcvd
                                                                   'in_b_bal_rcvd)
                                                                  (<=*
                                                                   'd13
                                                                   'd12))
                                                                 (list
                                                                  (if*
                                                                   (and*
                                                                    (or*
                                                                     (and*
                                                                      'd16
                                                                      (not*
                                                                       'd15))
                                                                     (and*
                                                                      'd15
                                                                      (eq*
                                                                       'd16
                                                                       #f)))
                                                                    (and*
                                                                     (bweq*
                                                                      'phase
                                                                      (bv #x07 8))
                                                                     (eq*
                                                                      #f
                                                                      (lt*
                                                                       (bv #x07 8)
                                                                       'in_c_bal_rcvd))))
                                                                   (list
                                                                    (<=*
                                                                     'in_c_val_vals
                                                                     'in_c_val_vals)
                                                                    (<=*
                                                                     'in_c_val_rcvd
                                                                     'in_c_val_rcvd)
                                                                    (<=*
                                                                     'in_c_bal_vals
                                                                     (bwxor*
                                                                      (bwnot*
                                                                       (shl*
                                                                        (bool->vect*
                                                                         'd17)
                                                                        'in_c_bal_rcvd))
                                                                      (bwor*
                                                                       (shl*
                                                                        (bv #x01 8)
                                                                        'in_c_bal_rcvd)
                                                                       (bwnot*
                                                                        'in_c_bal_vals))))
                                                                    (<=*
                                                                     'in_c_bal_rcvd
                                                                     (add*
                                                                      (bv #x01 8)
                                                                      'in_c_bal_rcvd))
                                                                    (<=*
                                                                     'd16
                                                                     'd15))
                                                                   (list
                                                                    (if*
                                                                     (and*
                                                                      (or*
                                                                       (and*
                                                                        (not*
                                                                         'd16)
                                                                        'd15)
                                                                       (and*
                                                                        'd16
                                                                        (not*
                                                                         'd15)))
                                                                      (and*
                                                                       (lt*
                                                                        (bv #x07 8)
                                                                        'in_c_bal_rcvd)
                                                                       (and*
                                                                        (eq*
                                                                         #f
                                                                         (lt*
                                                                          (bv #x07 8)
                                                                          'in_c_val_rcvd))
                                                                        (bweq*
                                                                         'phase
                                                                         (bv #x07 8)))))
                                                                     (list
                                                                      (<=*
                                                                       'in_c_val_vals
                                                                       (bwxor*
                                                                        (bwor*
                                                                         (bwnot*
                                                                          'in_c_val_vals)
                                                                         (shl*
                                                                          (bv #x01 8)
                                                                          'in_c_val_rcvd))
                                                                        (bwnot*
                                                                         (shl*
                                                                          (bool->vect*
                                                                           'd17)
                                                                          'in_c_val_rcvd))))
                                                                      (<=*
                                                                       'in_c_val_rcvd
                                                                       (add*
                                                                        'in_c_val_rcvd
                                                                        (bv #x01 8)))
                                                                      (<=*
                                                                       'in_c_bal_vals
                                                                       'in_c_bal_vals)
                                                                      (<=*
                                                                       'in_c_bal_rcvd
                                                                       'in_c_bal_rcvd)
                                                                      (<=*
                                                                       'd16
                                                                       'd15))
                                                                     (list
                                                                      (if*
                                                                       (and*
                                                                        (lt*
                                                                         (bv #x07 8)
                                                                         'in_a_val_rcvd)
                                                                        (and*
                                                                         (and*
                                                                          (lt*
                                                                           (bv #x07 8)
                                                                           'in_c_val_rcvd)
                                                                          (bweq*
                                                                           (bv #x07 8)
                                                                           'phase))
                                                                         (lt*
                                                                          (bv #x07 8)
                                                                          'in_b_val_rcvd)))
                                                                       (list
                                                                        (<=*
                                                                         'phase
                                                                         (bv #x08 8))
                                                                        (<=*
                                                                         'c_mval
                                                                         'in_c_val_vals)
                                                                        (<=*
                                                                         'b_mval
                                                                         'in_b_val_vals)
                                                                        (<=*
                                                                         'a_mval
                                                                         'in_a_val_vals)
                                                                        (<=*
                                                                         'c_mbal
                                                                         'in_c_bal_vals)
                                                                        (<=*
                                                                         'b_mbal
                                                                         'in_b_bal_vals)
                                                                        (<=*
                                                                         'a_mbal
                                                                         'in_a_bal_vals))
                                                                       (list
                                                                        (if*
                                                                         (and*
                                                                          (bweq*
                                                                           'a_mval
                                                                           'value)
                                                                          (and*
                                                                           (bweq*
                                                                            'value
                                                                            'b_mval)
                                                                           (and*
                                                                            (bweq*
                                                                             'value
                                                                             'c_mval)
                                                                            (bweq*
                                                                             'phase
                                                                             (bv #x08 8)))))
                                                                         (list
                                                                          (<=*
                                                                           'phase
                                                                           (bv #x00 8)))
                                                                         (list
                                                                          (if*
                                                                           (bweq*
                                                                            'phase
                                                                            (bv #x08 8))
                                                                           (list
                                                                            (<=*
                                                                             'phase
                                                                             (bv #xff 8)))
                                                                           '()))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

;;cpu time: 1033522 real time: 7237575 gc time: 620494
(define verilog-proposer
  (verilog-module*
   'proposer
   '(d15 d16 d17 d12 d13 d14 d9 d10 d11 d6 d7 d8 d3 d4 d5 d0 d1 d2 clock reset)
   (list
    (reg* 8 'in_c_val_rcvd)
    (reg* 8 'in_c_val_vals)
    (reg* 8 'in_b_val_rcvd)
    (reg* 8 'in_b_val_vals)
    (reg* 8 'in_a_val_rcvd)
    (reg* 8 'in_a_val_vals)
    (reg* 8 'in_c_bal_rcvd)
    (reg* 8 'in_c_bal_vals)
    (reg* 8 'in_b_bal_rcvd)
    (reg* 8 'in_b_bal_vals)
    (reg* 8 'in_a_bal_rcvd)
    (reg* 8 'in_a_bal_vals)
    (reg* 8 'out_c_val_sent)
    (reg* 8 'out_c_val_vals)
    (reg* 8 'out_b_val_sent)
    (reg* 8 'out_b_val_vals)
    (reg* 8 'out_a_val_sent)
    (reg* 8 'out_a_val_vals)
    (reg* 8 'out_c_bal_sent)
    (reg* 8 'out_c_bal_vals)
    (reg* 8 'out_b_bal_sent)
    (reg* 8 'out_b_bal_vals)
    (reg* 8 'out_a_bal_sent)
    (reg* 8 'out_a_bal_vals)
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
    (reg* 8 'c_mval)
    (reg* 8 'b_mval)
    (reg* 8 'a_mval)
    (reg* 8 'c_mbal)
    (reg* 8 'b_mbal)
    (reg* 8 'a_mbal)
    (reg* 8 'phase)
    (reg* 8 'value)
    (reg* 8 'ballot)
    (input* (wire* 1 'clock))
    (input* (wire* 1 'reset)))
   (list
    (always*
     (or* (posedge* 'clock) (posedge* 'reset))
     (list
      (if*
       'reset
       (list
        (<=* 'phase (bv #x01 8))
        (<=* 'value (bv #x20 8))
        (<=* 'ballot (bv #x01 8)))
       (list
        (if*
         (bweq* 'ballot (bv #xff 8))
         (list (<=* 'phase (bv #xff 8)))
         (list
          (if*
           (bweq* (bv #x01 8) 'phase)
           (list
            (<=* 'phase (bv #x02 8))
            (<=* 'out_c_bal_vals 'ballot)
            (<=* 'out_c_bal_sent (bv #x00 8))
            (<=* 'out_b_bal_vals 'ballot)
            (<=* 'out_b_bal_sent (bv #x00 8))
            (<=* 'out_a_bal_vals 'ballot)
            (<=* 'out_a_bal_sent (bv #x00 8)))
           (list
            (if*
             (and*
              (and*
               (bweq* 'phase (bv #x02 8))
               (eq* #f (lt* (bv #x07 8) 'out_a_bal_sent)))
              (not* (or* (and* 'd0 (eq* #f 'd1)) (and* (eq* #f 'd0) 'd1))))
             (list
              (<=* 'out_a_bal_vals 'out_a_bal_vals)
              (<=* 'out_a_bal_sent (add* 'out_a_bal_sent (bv #x01 8)))
              (<=*
               'd2
               (eq*
                (eq*
                 (bv #x00 8)
                 (bwand* 'out_a_bal_vals (shl* (bv #x01 8) 'out_a_bal_sent)))
                #f))
              (<=* 'd0 (eq* 'd1 #f)))
             (list
              (if*
               (and*
                (and*
                 (eq* #f (lt* (bv #x07 8) 'out_b_bal_sent))
                 (bweq* 'phase (bv #x02 8)))
                (eq* 'd4 'd3))
               (list
                (<=* 'out_b_bal_vals 'out_b_bal_vals)
                (<=* 'out_b_bal_sent (add* 'out_b_bal_sent (bv #x01 8)))
                (<=*
                 'd5
                 (eq*
                  (bv #xff 8)
                  (bwor* (bv #xfe 8) (shr* 'out_b_bal_vals 'out_b_bal_sent))))
                (<=* 'd3 (eq* 'd4 #f)))
               (list
                (if*
                 (and*
                  (and*
                   (bweq* (bv #x02 8) 'phase)
                   (eq* #f (lt* (bv #x07 8) 'out_c_bal_sent)))
                  (not* (or* (and* 'd6 (not* 'd7)) (and* (eq* #f 'd6) 'd7))))
                 (list
                  (<=* 'out_c_bal_vals 'out_c_bal_vals)
                  (<=* 'out_c_bal_sent (add* 'out_c_bal_sent (bv #x01 8)))
                  (<=*
                   'd8
                   (eq*
                    (bwand*
                     (bwnot* 'out_c_bal_vals)
                     (shl* (bv #x01 8) 'out_c_bal_sent))
                    (bv #x00 8)))
                  (<=* 'd6 (not* 'd7)))
                 (list
                  (if*
                   (and*
                    (and*
                     (lt* (bv #x07 8) 'out_b_bal_sent)
                     (and*
                      (bweq* 'phase (bv #x02 8))
                      (lt* (bv #x07 8) 'out_c_bal_sent)))
                    (lt* (bv #x07 8) 'out_a_bal_sent))
                   (list
                    (<=* 'phase (bv #x03 8))
                    (<=* 'in_c_val_vals (bv #x00 8))
                    (<=* 'in_c_val_rcvd (bv #x00 8))
                    (<=* 'in_b_val_vals (bv #x00 8))
                    (<=* 'in_b_val_rcvd (bv #x00 8))
                    (<=* 'in_a_val_vals (bv #x00 8))
                    (<=* 'in_a_val_rcvd (bv #x00 8))
                    (<=* 'in_c_bal_vals (bv #x00 8))
                    (<=* 'in_c_bal_rcvd (bv #x00 8))
                    (<=* 'in_b_bal_vals (bv #x00 8))
                    (<=* 'in_b_bal_rcvd (bv #x00 8))
                    (<=* 'in_a_bal_vals (bv #x00 8))
                    (<=* 'in_a_bal_rcvd (bv #x00 8)))
                   (list
                    (if*
                     (and*
                      (and*
                       (bweq* 'phase (bv #x03 8))
                       (eq* #f (lt* (bv #x07 8) 'in_a_bal_rcvd)))
                      (or* (and* 'd9 (not* 'd10)) (and* 'd10 (eq* 'd9 #f))))
                     (list
                      (<=* 'in_a_val_vals 'in_a_val_vals)
                      (<=* 'in_a_val_rcvd 'in_a_val_rcvd)
                      (<=*
                       'in_a_bal_vals
                       (bwxor*
                        (shl*
                         (bwxor* (bool->vect* 'd11) (bv #x01 8))
                         'in_a_bal_rcvd)
                        (bwor*
                         'in_a_bal_vals
                         (shl* (bv #x01 8) 'in_a_bal_rcvd))))
                      (<=* 'in_a_bal_rcvd (add* (bv #x01 8) 'in_a_bal_rcvd))
                      (<=* 'd10 'd9))
                     (list
                      (if*
                       (and*
                        (and*
                         (lt* (bv #x07 8) 'in_a_bal_rcvd)
                         (and*
                          (lt* 'in_a_val_rcvd (bv #x08 8))
                          (bweq* (bv #x03 8) 'phase)))
                        (or* (and* 'd9 (eq* #f 'd10)) (and* (eq* 'd9 #f) 'd10)))
                       (list
                        (<=*
                         'in_a_val_vals
                         (bwxor*
                          (bwxor*
                           (shl* (bool->vect* 'd11) 'in_a_val_rcvd)
                           (bv #xff 8))
                          (bwor*
                           (shl* (bv #x01 8) 'in_a_val_rcvd)
                           (bwnot* 'in_a_val_vals))))
                        (<=* 'in_a_val_rcvd (add* 'in_a_val_rcvd (bv #x01 8)))
                        (<=* 'in_a_bal_vals 'in_a_bal_vals)
                        (<=* 'in_a_bal_rcvd 'in_a_bal_rcvd)
                        (<=* 'd10 'd9))
                       (list
                        (if*
                         (and*
                          (or* (and* (not* 'd12) 'd13) (and* (not* 'd13) 'd12))
                          (and*
                           (bweq* (bv #x03 8) 'phase)
                           (eq* #f (lt* (bv #x07 8) 'in_b_bal_rcvd))))
                         (list
                          (<=* 'in_b_val_vals 'in_b_val_vals)
                          (<=* 'in_b_val_rcvd 'in_b_val_rcvd)
                          (<=*
                           'in_b_bal_vals
                           (bwxor*
                            (bwor*
                             (shl* (bv #x01 8) 'in_b_bal_rcvd)
                             (bwnot* 'in_b_bal_vals))
                            (bwxor*
                             (shl* (bool->vect* 'd14) 'in_b_bal_rcvd)
                             (bv #xff 8))))
                          (<=* 'in_b_bal_rcvd (add* 'in_b_bal_rcvd (bv #x01 8)))
                          (<=* 'd13 'd12))
                         (list
                          (if*
                           (and*
                            (and*
                             (and*
                              (eq* #f (lt* (bv #x07 8) 'in_b_val_rcvd))
                              (bweq* (bv #x03 8) 'phase))
                             (lt* (bv #x07 8) 'in_b_bal_rcvd))
                            (or*
                             (and* 'd13 (eq* 'd12 #f))
                             (and* 'd12 (eq* 'd13 #f))))
                           (list
                            (<=*
                             'in_b_val_vals
                             (bwxor*
                              (bwnot* (shl* (bool->vect* 'd14) 'in_b_val_rcvd))
                              (bwor*
                               (shl* (bv #x01 8) 'in_b_val_rcvd)
                               (bwnot* 'in_b_val_vals))))
                            (<=*
                             'in_b_val_rcvd
                             (add* (bv #x01 8) 'in_b_val_rcvd))
                            (<=* 'in_b_bal_vals 'in_b_bal_vals)
                            (<=* 'in_b_bal_rcvd 'in_b_bal_rcvd)
                            (<=* 'd13 'd12))
                           (list
                            (if*
                             (and*
                              (or*
                               (and* 'd16 (not* 'd15))
                               (and* (eq* 'd16 #f) 'd15))
                              (and*
                               (bweq* (bv #x03 8) 'phase)
                               (eq* #f (lt* (bv #x07 8) 'in_c_bal_rcvd))))
                             (list
                              (<=* 'in_c_val_vals 'in_c_val_vals)
                              (<=* 'in_c_val_rcvd 'in_c_val_rcvd)
                              (<=*
                               'in_c_bal_vals
                               (bwxor*
                                (bwor*
                                 (shl* (bv #x01 8) 'in_c_bal_rcvd)
                                 'in_c_bal_vals)
                                (shl*
                                 (bwxor* (bv #x01 8) (bool->vect* 'd17))
                                 'in_c_bal_rcvd)))
                              (<=*
                               'in_c_bal_rcvd
                               (add* (bv #x01 8) 'in_c_bal_rcvd))
                              (<=* 'd16 'd15))
                             (list
                              (if*
                               (and*
                                (or*
                                 (and* 'd15 (not* 'd16))
                                 (and* 'd16 (not* 'd15)))
                                (and*
                                 (lt* (bv #x07 8) 'in_c_bal_rcvd)
                                 (and*
                                  (eq* #f (lt* (bv #x07 8) 'in_c_val_rcvd))
                                  (bweq* 'phase (bv #x03 8)))))
                               (list
                                (<=*
                                 'in_c_val_vals
                                 (bwxor*
                                  (bwand*
                                   'in_c_val_vals
                                   (shl* (bv #x01 8) 'in_c_val_rcvd))
                                  (bwxor*
                                   'in_c_val_vals
                                   (shl* (bool->vect* 'd17) 'in_c_val_rcvd))))
                                (<=*
                                 'in_c_val_rcvd
                                 (add* (bv #x01 8) 'in_c_val_rcvd))
                                (<=* 'in_c_bal_vals 'in_c_bal_vals)
                                (<=* 'in_c_bal_rcvd 'in_c_bal_rcvd)
                                (<=* 'd16 'd15))
                               (list
                                (if*
                                 (and*
                                  (lt* (bv #x07 8) 'in_a_val_rcvd)
                                  (and*
                                   (lt* (bv #x07 8) 'in_b_val_rcvd)
                                   (and*
                                    (bweq* (bv #x03 8) 'phase)
                                    (lt* (bv #x07 8) 'in_c_val_rcvd))))
                                 (list
                                  (<=* 'phase (bv #x04 8))
                                  (<=* 'c_mval 'in_c_val_vals)
                                  (<=* 'b_mval 'in_b_val_vals)
                                  (<=* 'a_mval 'in_a_val_vals)
                                  (<=* 'c_mbal 'in_c_bal_vals)
                                  (<=* 'b_mbal 'in_b_bal_vals)
                                  (<=* 'a_mbal 'in_a_bal_vals))
                                 (list
                                  (if*
                                   (and*
                                    (and*
                                     (and*
                                      (bweq* 'phase (bv #x04 8))
                                      (bweq* (bv #x00 8) 'c_mbal))
                                     (bweq* 'b_mbal (bv #x00 8)))
                                    (lt* 'a_mbal (bv #x01 8)))
                                   (list
                                    (<=* 'phase (bv #x05 8))
                                    (<=* 'value 'value))
                                   (list
                                    (if*
                                     (and*
                                      (or*
                                       (lt* 'b_mbal 'a_mbal)
                                       (bweq* 'b_mbal 'a_mbal))
                                      (and*
                                       (or*
                                        (bweq* 'a_mbal 'c_mbal)
                                        (lt* 'c_mbal 'a_mbal))
                                       (bweq* (bv #x04 8) 'phase)))
                                     (list
                                      (<=* 'phase (bv #x05 8))
                                      (<=* 'value 'a_mval))
                                     (list
                                      (if*
                                       (and*
                                        (bweq* (bv #x04 8) 'phase)
                                        (or*
                                         (bweq* 'b_mbal 'c_mbal)
                                         (lt* 'c_mbal 'b_mbal)))
                                       (list
                                        (<=* 'phase (bv #x05 8))
                                        (<=* 'value 'b_mval))
                                       (list
                                        (if*
                                         (bweq* (bv #x04 8) 'phase)
                                         (list
                                          (<=* 'phase (bv #x05 8))
                                          (<=* 'value 'c_mval))
                                         (list
                                          (if*
                                           (bweq* (bv #x05 8) 'phase)
                                           (list
                                            (<=* 'phase (bv #x06 8))
                                            (<=* 'out_c_val_vals 'value)
                                            (<=* 'out_c_val_sent (bv #x00 8))
                                            (<=* 'out_b_val_vals 'value)
                                            (<=* 'out_b_val_sent (bv #x00 8))
                                            (<=* 'out_a_val_vals 'value)
                                            (<=* 'out_a_val_sent (bv #x00 8))
                                            (<=* 'out_c_bal_vals 'ballot)
                                            (<=* 'out_c_bal_sent (bv #x00 8))
                                            (<=* 'out_b_bal_vals 'ballot)
                                            (<=* 'out_b_bal_sent (bv #x00 8))
                                            (<=* 'out_a_bal_vals 'ballot)
                                            (<=* 'out_a_bal_sent (bv #x00 8)))
                                           (list
                                            (if*
                                             (and*
                                              (eq* 'd1 'd0)
                                              (and*
                                               (bweq* 'phase (bv #x06 8))
                                               (not*
                                                (lt*
                                                 (bv #x07 8)
                                                 'out_a_bal_sent))))
                                             (list
                                              (<=*
                                               'out_a_val_vals
                                               'out_a_val_vals)
                                              (<=*
                                               'out_a_val_sent
                                               'out_a_val_sent)
                                              (<=*
                                               'out_a_bal_vals
                                               'out_a_bal_vals)
                                              (<=*
                                               'out_a_bal_sent
                                               (add*
                                                'out_a_bal_sent
                                                (bv #x01 8)))
                                              (<=*
                                               'd2
                                               (lt*
                                                (bwand*
                                                 (shl*
                                                  (bv #x01 8)
                                                  'out_a_bal_sent)
                                                 (bwnot* 'out_a_bal_vals))
                                                (bv #x01 8)))
                                              (<=* 'd0 (eq* 'd1 #f)))
                                             (list
                                              (if*
                                               (and*
                                                (and*
                                                 (lt*
                                                  (bv #x07 8)
                                                  'out_a_bal_sent)
                                                 (and*
                                                  (bweq* 'phase (bv #x06 8))
                                                  (not*
                                                   (lt*
                                                    (bv #x07 8)
                                                    'out_a_val_sent))))
                                                (eq* 'd1 'd0))
                                               (list
                                                (<=*
                                                 'out_a_val_vals
                                                 'out_a_val_vals)
                                                (<=*
                                                 'out_a_val_sent
                                                 (add*
                                                  'out_a_val_sent
                                                  (bv #x01 8)))
                                                (<=*
                                                 'out_a_bal_vals
                                                 'out_a_bal_vals)
                                                (<=*
                                                 'out_a_bal_sent
                                                 'out_a_bal_sent)
                                                (<=*
                                                 'd2
                                                 (bweq*
                                                  (bwand*
                                                   (shr*
                                                    'out_a_val_vals
                                                    'out_a_val_sent)
                                                   (bv #x01 8))
                                                  (bv #x01 8)))
                                                (<=* 'd0 (eq* 'd1 #f)))
                                               (list
                                                (if*
                                                 (and*
                                                  (not*
                                                   (or*
                                                    (and* (eq* #f 'd4) 'd3)
                                                    (and* 'd4 (eq* 'd3 #f))))
                                                  (and*
                                                   (bweq* 'phase (bv #x06 8))
                                                   (eq*
                                                    (lt*
                                                     (bv #x07 8)
                                                     'out_b_bal_sent)
                                                    #f)))
                                                 (list
                                                  (<=*
                                                   'out_b_val_vals
                                                   'out_b_val_vals)
                                                  (<=*
                                                   'out_b_val_sent
                                                   'out_b_val_sent)
                                                  (<=*
                                                   'out_b_bal_vals
                                                   'out_b_bal_vals)
                                                  (<=*
                                                   'out_b_bal_sent
                                                   (add*
                                                    'out_b_bal_sent
                                                    (bv #x01 8)))
                                                  (<=*
                                                   'd5
                                                   (eq*
                                                    (bwand*
                                                     (bwnot* 'out_b_bal_vals)
                                                     (shl*
                                                      (bv #x01 8)
                                                      'out_b_bal_sent))
                                                    (bv #x00 8)))
                                                  (<=* 'd3 (not* 'd3)))
                                                 (list
                                                  (if*
                                                   (and*
                                                    (and*
                                                     (lt*
                                                      (bv #x07 8)
                                                      'out_b_bal_sent)
                                                     (and*
                                                      (lt*
                                                       'out_b_val_sent
                                                       (bv #x08 8))
                                                      (bweq*
                                                       'phase
                                                       (bv #x06 8))))
                                                    (not*
                                                     (or*
                                                      (and* (not* 'd3) 'd4)
                                                      (and* 'd3 (eq* 'd4 #f)))))
                                                   (list
                                                    (<=*
                                                     'out_b_val_vals
                                                     'out_b_val_vals)
                                                    (<=*
                                                     'out_b_val_sent
                                                     (add*
                                                      'out_b_val_sent
                                                      (bv #x01 8)))
                                                    (<=*
                                                     'out_b_bal_vals
                                                     'out_b_bal_vals)
                                                    (<=*
                                                     'out_b_bal_sent
                                                     'out_b_bal_sent)
                                                    (<=*
                                                     'd5
                                                     (not*
                                                      (bweq*
                                                       (bv #x00 8)
                                                       (bwand*
                                                        (shr*
                                                         'out_b_val_vals
                                                         'out_b_val_sent)
                                                        (bv #x01 8)))))
                                                    (<=* 'd3 (not* 'd4)))
                                                   (list
                                                    (if*
                                                     (and*
                                                      (and*
                                                       (bweq* 'phase (bv #x06 8))
                                                       (not*
                                                        (lt*
                                                         (bv #x07 8)
                                                         'out_c_bal_sent)))
                                                      (eq* 'd6 'd7))
                                                     (list
                                                      (<=*
                                                       'out_c_val_vals
                                                       'out_c_val_vals)
                                                      (<=*
                                                       'out_c_val_sent
                                                       'out_c_val_sent)
                                                      (<=*
                                                       'out_c_bal_vals
                                                       'out_c_bal_vals)
                                                      (<=*
                                                       'out_c_bal_sent
                                                       (add*
                                                        (bv #x01 8)
                                                        'out_c_bal_sent))
                                                      (<=*
                                                       'd8
                                                       (bweq*
                                                        (bwand*
                                                         (shl*
                                                          (bv #x01 8)
                                                          'out_c_bal_sent)
                                                         (bwxor*
                                                          (bv #xff 8)
                                                          'out_c_bal_vals))
                                                        (bv #x00 8)))
                                                      (<=* 'd6 (not* 'd6)))
                                                     (list
                                                      (if*
                                                       (and*
                                                        (and*
                                                         (and*
                                                          (bweq*
                                                           (bv #x06 8)
                                                           'phase)
                                                          (eq*
                                                           #f
                                                           (lt*
                                                            (bv #x07 8)
                                                            'out_c_val_sent)))
                                                         (lt*
                                                          (bv #x07 8)
                                                          'out_c_bal_sent))
                                                        (eq* 'd6 'd7))
                                                       (list
                                                        (<=*
                                                         'out_c_val_vals
                                                         'out_c_val_vals)
                                                        (<=*
                                                         'out_c_val_sent
                                                         (add*
                                                          (bv #x01 8)
                                                          'out_c_val_sent))
                                                        (<=*
                                                         'out_c_bal_vals
                                                         'out_c_bal_vals)
                                                        (<=*
                                                         'out_c_bal_sent
                                                         'out_c_bal_sent)
                                                        (<=*
                                                         'd8
                                                         (eq*
                                                          (bwor*
                                                           (shr*
                                                            'out_c_val_vals
                                                            'out_c_val_sent)
                                                           (bv #x01 8))
                                                          (shr*
                                                           'out_c_val_vals
                                                           'out_c_val_sent)))
                                                        (<=* 'd6 (eq* 'd7 #f)))
                                                       (list
                                                        (if*
                                                         (and*
                                                          (and*
                                                           (and*
                                                            (bweq*
                                                             (bv #x06 8)
                                                             'phase)
                                                            (lt*
                                                             (bv #x07 8)
                                                             'out_c_val_sent))
                                                           (lt*
                                                            (bv #x07 8)
                                                            'out_b_val_sent))
                                                          (lt*
                                                           (bv #x07 8)
                                                           'out_a_val_sent))
                                                         (list
                                                          (<=*
                                                           'phase
                                                           (bv #x07 8))
                                                          (<=*
                                                           'in_c_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_val_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_val_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_c_bal_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_b_bal_rcvd
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_bal_vals
                                                           (bv #x00 8))
                                                          (<=*
                                                           'in_a_bal_rcvd
                                                           (bv #x00 8)))
                                                         (list
                                                          (if*
                                                           (and*
                                                            (or*
                                                             (and*
                                                              (eq* #f 'd9)
                                                              'd10)
                                                             (and*
                                                              (eq* 'd10 #f)
                                                              'd9))
                                                            (and*
                                                             (bweq*
                                                              (bv #x07 8)
                                                              'phase)
                                                             (eq*
                                                              #f
                                                              (lt*
                                                               (bv #x07 8)
                                                               'in_a_bal_rcvd))))
                                                           (list
                                                            (<=*
                                                             'in_a_val_vals
                                                             'in_a_val_vals)
                                                            (<=*
                                                             'in_a_val_rcvd
                                                             'in_a_val_rcvd)
                                                            (<=*
                                                             'in_a_bal_vals
                                                             (bwxor*
                                                              (shl*
                                                               (shr*
                                                                (bv #x01 8)
                                                                (bool->vect*
                                                                 'd11))
                                                               'in_a_bal_rcvd)
                                                              (bwor*
                                                               (shl*
                                                                (bv #x01 8)
                                                                'in_a_bal_rcvd)
                                                               'in_a_bal_vals)))
                                                            (<=*
                                                             'in_a_bal_rcvd
                                                             (add*
                                                              'in_a_bal_rcvd
                                                              (bv #x01 8)))
                                                            (<=* 'd10 'd9))
                                                           (list
                                                            (if*
                                                             (and*
                                                              (and*
                                                               (and*
                                                                (not*
                                                                 (lt*
                                                                  (bv #x07 8)
                                                                  'in_a_val_rcvd))
                                                                (bweq*
                                                                 'phase
                                                                 (bv #x07 8)))
                                                               (lt*
                                                                (bv #x07 8)
                                                                'in_a_bal_rcvd))
                                                              (or*
                                                               (and*
                                                                'd10
                                                                (not* 'd9))
                                                               (and*
                                                                (not* 'd10)
                                                                'd9)))
                                                             (list
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
                                                                  (bv #x01 8)
                                                                  'in_a_val_rcvd)
                                                                 (bwnot*
                                                                  'in_a_val_vals))))
                                                              (<=*
                                                               'in_a_val_rcvd
                                                               (add*
                                                                (bv #x01 8)
                                                                'in_a_val_rcvd))
                                                              (<=*
                                                               'in_a_bal_vals
                                                               'in_a_bal_vals)
                                                              (<=*
                                                               'in_a_bal_rcvd
                                                               'in_a_bal_rcvd)
                                                              (<=* 'd10 'd9))
                                                             (list
                                                              (if*
                                                               (and*
                                                                (and*
                                                                 (eq*
                                                                  #f
                                                                  (lt*
                                                                   (bv #x07 8)
                                                                   'in_b_bal_rcvd))
                                                                 (bweq*
                                                                  (bv #x07 8)
                                                                  'phase))
                                                                (or*
                                                                 (and*
                                                                  'd12
                                                                  (eq* 'd13 #f))
                                                                 (and*
                                                                  'd13
                                                                  (eq*
                                                                   'd12
                                                                   #f))))
                                                               (list
                                                                (<=*
                                                                 'in_b_val_vals
                                                                 'in_b_val_vals)
                                                                (<=*
                                                                 'in_b_val_rcvd
                                                                 'in_b_val_rcvd)
                                                                (<=*
                                                                 'in_b_bal_vals
                                                                 (bwxor*
                                                                  (bwxor*
                                                                   (bv #xff 8)
                                                                   (shl*
                                                                    (bool->vect*
                                                                     'd14)
                                                                    'in_b_bal_rcvd))
                                                                  (bwor*
                                                                   (shl*
                                                                    (bv #x01 8)
                                                                    'in_b_bal_rcvd)
                                                                   (bwnot*
                                                                    'in_b_bal_vals))))
                                                                (<=*
                                                                 'in_b_bal_rcvd
                                                                 (add*
                                                                  (bv #x01 8)
                                                                  'in_b_bal_rcvd))
                                                                (<=* 'd13 'd12))
                                                               (list
                                                                (if*
                                                                 (and*
                                                                  (and*
                                                                   (and*
                                                                    (bweq*
                                                                     (bv #x07 8)
                                                                     'phase)
                                                                    (eq*
                                                                     #f
                                                                     (lt*
                                                                      (bv #x07 8)
                                                                      'in_b_val_rcvd)))
                                                                   (lt*
                                                                    (bv #x07 8)
                                                                    'in_b_bal_rcvd))
                                                                  (or*
                                                                   (and*
                                                                    'd12
                                                                    (eq*
                                                                     #f
                                                                     'd13))
                                                                   (and*
                                                                    (eq* #f 'd12)
                                                                    'd13)))
                                                                 (list
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
                                                                      (bv #x01 8)
                                                                      'in_b_val_rcvd)
                                                                     (bwxor*
                                                                      'in_b_val_vals
                                                                      (bv #xff 8)))))
                                                                  (<=*
                                                                   'in_b_val_rcvd
                                                                   (add*
                                                                    (bv #x01 8)
                                                                    'in_b_val_rcvd))
                                                                  (<=*
                                                                   'in_b_bal_vals
                                                                   'in_b_bal_vals)
                                                                  (<=*
                                                                   'in_b_bal_rcvd
                                                                   'in_b_bal_rcvd)
                                                                  (<=*
                                                                   'd13
                                                                   'd12))
                                                                 (list
                                                                  (if*
                                                                   (and*
                                                                    (or*
                                                                     (and*
                                                                      'd16
                                                                      (not*
                                                                       'd15))
                                                                     (and*
                                                                      'd15
                                                                      (eq*
                                                                       'd16
                                                                       #f)))
                                                                    (and*
                                                                     (bweq*
                                                                      'phase
                                                                      (bv #x07 8))
                                                                     (eq*
                                                                      #f
                                                                      (lt*
                                                                       (bv #x07 8)
                                                                       'in_c_bal_rcvd))))
                                                                   (list
                                                                    (<=*
                                                                     'in_c_val_vals
                                                                     'in_c_val_vals)
                                                                    (<=*
                                                                     'in_c_val_rcvd
                                                                     'in_c_val_rcvd)
                                                                    (<=*
                                                                     'in_c_bal_vals
                                                                     (bwxor*
                                                                      (bwnot*
                                                                       (shl*
                                                                        (bool->vect*
                                                                         'd17)
                                                                        'in_c_bal_rcvd))
                                                                      (bwor*
                                                                       (shl*
                                                                        (bv #x01 8)
                                                                        'in_c_bal_rcvd)
                                                                       (bwnot*
                                                                        'in_c_bal_vals))))
                                                                    (<=*
                                                                     'in_c_bal_rcvd
                                                                     (add*
                                                                      (bv #x01 8)
                                                                      'in_c_bal_rcvd))
                                                                    (<=*
                                                                     'd16
                                                                     'd15))
                                                                   (list
                                                                    (if*
                                                                     (and*
                                                                      (or*
                                                                       (and*
                                                                        (not*
                                                                         'd16)
                                                                        'd15)
                                                                       (and*
                                                                        'd16
                                                                        (not*
                                                                         'd15)))
                                                                      (and*
                                                                       (lt*
                                                                        (bv #x07 8)
                                                                        'in_c_bal_rcvd)
                                                                       (and*
                                                                        (eq*
                                                                         #f
                                                                         (lt*
                                                                          (bv #x07 8)
                                                                          'in_c_val_rcvd))
                                                                        (bweq*
                                                                         'phase
                                                                         (bv #x07 8)))))
                                                                     (list
                                                                      (<=*
                                                                       'in_c_val_vals
                                                                       (bwxor*
                                                                        (bwor*
                                                                         (bwnot*
                                                                          'in_c_val_vals)
                                                                         (shl*
                                                                          (bv #x01 8)
                                                                          'in_c_val_rcvd))
                                                                        (bwnot*
                                                                         (shl*
                                                                          (bool->vect*
                                                                           'd17)
                                                                          'in_c_val_rcvd))))
                                                                      (<=*
                                                                       'in_c_val_rcvd
                                                                       (add*
                                                                        'in_c_val_rcvd
                                                                        (bv #x01 8)))
                                                                      (<=*
                                                                       'in_c_bal_vals
                                                                       'in_c_bal_vals)
                                                                      (<=*
                                                                       'in_c_bal_rcvd
                                                                       'in_c_bal_rcvd)
                                                                      (<=*
                                                                       'd16
                                                                       'd15))
                                                                     (list
                                                                      (if*
                                                                       (and*
                                                                        (lt*
                                                                         (bv #x07 8)
                                                                         'in_a_val_rcvd)
                                                                        (and*
                                                                         (and*
                                                                          (lt*
                                                                           (bv #x07 8)
                                                                           'in_c_val_rcvd)
                                                                          (bweq*
                                                                           (bv #x07 8)
                                                                           'phase))
                                                                         (lt*
                                                                          (bv #x07 8)
                                                                          'in_b_val_rcvd)))
                                                                       (list
                                                                        (<=*
                                                                         'phase
                                                                         (bv #x08 8))
                                                                        (<=*
                                                                         'c_mval
                                                                         'in_c_val_vals)
                                                                        (<=*
                                                                         'b_mval
                                                                         'in_b_val_vals)
                                                                        (<=*
                                                                         'a_mval
                                                                         'in_a_val_vals)
                                                                        (<=*
                                                                         'c_mbal
                                                                         'in_c_bal_vals)
                                                                        (<=*
                                                                         'b_mbal
                                                                         'in_b_bal_vals)
                                                                        (<=*
                                                                         'a_mbal
                                                                         'in_a_bal_vals))
                                                                       (list
                                                                        (if*
                                                                         (and*
                                                                          (bweq*
                                                                           'a_mval
                                                                           'value)
                                                                          (and*
                                                                           (bweq*
                                                                            'value
                                                                            'b_mval)
                                                                           (and*
                                                                            (bweq*
                                                                             'value
                                                                             'c_mval)
                                                                            (bweq*
                                                                             'phase
                                                                             (bv #x08 8)))))
                                                                         (list
                                                                          (<=*
                                                                           'phase
                                                                           (bv #x00 8)))
                                                                         (list
                                                                          (if*
                                                                           (bweq*
                                                                            'phase
                                                                            (bv #x08 8))
                                                                           (list
                                                                            (<=*
                                                                             'phase
                                                                             (bv #xff 8)))
                                                                           '()))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

;; cpu time: 61341 real time: 4400498 gc time: 10054
(define verilog-acceptor
  (verilog-module*
 'acceptor
 '(d3 d4 d5 d0 d1 d2 clock reset)
 (list
  (reg* 8 'in_prop_val_rcvd)
  (reg* 8 'in_prop_val_vals)
  (reg* 8 'in_prop_bal_rcvd)
  (reg* 8 'in_prop_bal_vals)
  (reg* 8 'out_prop_val_sent)
  (reg* 8 'out_prop_val_vals)
  (reg* 8 'out_prop_bal_sent)
  (reg* 8 'out_prop_bal_vals)
  (input* (wire* 1 'd3))
  (output* (reg* 1 'd4))
  (input* (wire* 1 'd5))
  (output* (reg* 1 'd0))
  (input* (wire* 1 'd1))
  (output* (reg* 1 'd2))
  (reg* 8 'prop_mval)
  (reg* 8 'prop_mbal)
  (reg* 8 'prom_bal)
  (reg* 8 'phase)
  (reg* 8 'value)
  (reg* 8 'ballot)
  (input* (wire* 1 'clock))
  (input* (wire* 1 'reset)))
 (list
  (always*
   (or* (posedge* 'clock) (posedge* 'reset))
   (list
    (if*
     'reset
     (list
      (<=* 'in_prop_bal_vals (bv #x00 8))
      (<=* 'in_prop_bal_rcvd (bv #x00 8))
      (<=* 'prom_bal (bv #x00 8))
      (<=* 'phase (bv #x01 8))
      (<=* 'value (bv #x00 8))
      (<=* 'ballot (bv #x00 8)))
     (list
      (if*
       (bweq* (bv #x01 8) 'phase)
       (list
        (<=* 'phase (bv #x02 8))
        (<=* 'in_prop_bal_vals (bv #x00 8))
        (<=* 'in_prop_bal_rcvd (bv #x00 8)))
       (list
        (if*
         (and*
          (or* (and* (eq* #f 'd4) 'd3) (and* (not* 'd3) 'd4))
          (and*
           (eq* #f (lt* (bv #x07 8) 'in_prop_bal_rcvd))
           (bweq* (bv #x02 8) 'phase)))
         (list
          (<=*
           'in_prop_bal_vals
           (bwxor*
            (bwor*
             (bwnot* 'in_prop_bal_vals)
             (shl* (bv #x01 8) 'in_prop_bal_rcvd))
            (bwnot* (shl* (bool->vect* 'd5) 'in_prop_bal_rcvd))))
          (<=*
           'in_prop_bal_rcvd
           (bwnot* (add* (bwnot* 'in_prop_bal_rcvd) (bv #xff 8))))
          (<=* 'd4 'd3))
         (list
          (if*
           (and*
            (lt* (bv #x07 8) 'in_prop_bal_rcvd)
            (bweq* (bv #x02 8) 'phase))
           (list (<=* 'phase (bv #x03 8)) (<=* 'prop_mbal 'in_prop_bal_vals))
           (list
            (if*
             (and*
              (lt* 'ballot 'prop_mbal)
              (and* (bweq* 'phase (bv #x03 8)) (lt* 'prom_bal 'prop_mbal)))
             (list
              (<=* 'phase (bv #x04 8))
              (<=* 'prom_bal 'prop_mbal)
              (<=* 'out_prop_val_vals 'value)
              (<=* 'out_prop_val_sent (bv #x00 8))
              (<=* 'out_prop_bal_vals 'ballot)
              (<=* 'out_prop_bal_sent (bv #x00 8)))
             (list
              (if*
               (and*
                (and*
                 (bweq* (bv #x04 8) 'phase)
                 (eq* #f (lt* (bv #x07 8) 'out_prop_bal_sent)))
                (not* (or* (and* 'd0 (eq* 'd1 #f)) (and* 'd1 (eq* #f 'd0)))))
               (list
                (<=* 'out_prop_val_vals 'out_prop_val_vals)
                (<=* 'out_prop_val_sent 'out_prop_val_sent)
                (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                (<=* 'out_prop_bal_sent (add* 'out_prop_bal_sent (bv #x01 8)))
                (<=*
                 'd2
                 (eq*
                  (bwand*
                   'out_prop_bal_vals
                   (shl* (bv #x01 8) 'out_prop_bal_sent))
                  (shl* (bv #x01 8) 'out_prop_bal_sent)))
                (<=* 'd0 (not* 'd1)))
               (list
                (if*
                 (and*
                  (not* (or* (and* (eq* #f 'd0) 'd1) (and* 'd0 (eq* #f 'd1))))
                  (and*
                   (lt* (bv #x07 8) 'out_prop_bal_sent)
                   (and*
                    (eq* #f (lt* (bv #x07 8) 'out_prop_val_sent))
                    (bweq* (bv #x04 8) 'phase))))
                 (list
                  (<=* 'out_prop_val_vals 'out_prop_val_vals)
                  (<=*
                   'out_prop_val_sent
                   (add* 'out_prop_val_sent (bv #x01 8)))
                  (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                  (<=* 'out_prop_bal_sent 'out_prop_bal_sent)
                  (<=*
                   'd2
                   (eq*
                    (bv #x00 8)
                    (bwand*
                     (shl* (bv #x01 8) 'out_prop_val_sent)
                     (bwnot* 'out_prop_val_vals))))
                  (<=* 'd0 (not* 'd1)))
                 (list
                  (if*
                   (and*
                    (bweq* (bv #x04 8) 'phase)
                    (lt* (bv #x07 8) 'out_prop_val_sent))
                   (list
                    (<=* 'phase (bv #x05 8))
                    (<=* 'in_prop_val_vals (bv #x00 8))
                    (<=* 'in_prop_val_rcvd (bv #x00 8))
                    (<=* 'in_prop_bal_vals (bv #x00 8))
                    (<=* 'in_prop_bal_rcvd (bv #x00 8)))
                   (list
                    (if*
                     (and*
                      (and*
                       (eq* #f (lt* (bv #x07 8) 'in_prop_bal_rcvd))
                       (bweq* 'phase (bv #x05 8)))
                      (or* (and* (eq* 'd3 #f) 'd4) (and* 'd3 (eq* 'd4 #f))))
                     (list
                      (<=* 'in_prop_val_vals 'in_prop_val_vals)
                      (<=* 'in_prop_val_rcvd 'in_prop_val_rcvd)
                      (<=*
                       'in_prop_bal_vals
                       (bwxor*
                        (bwnot* (shl* (bool->vect* 'd5) 'in_prop_bal_rcvd))
                        (bwor*
                         (shl* (bv #x01 8) 'in_prop_bal_rcvd)
                         (bwnot* 'in_prop_bal_vals))))
                      (<=*
                       'in_prop_bal_rcvd
                       (add* 'in_prop_bal_rcvd (bv #x01 8)))
                      (<=* 'd4 'd3))
                     (list
                      (if*
                       (and*
                        (or* (and* 'd4 (eq* 'd3 #f)) (and* 'd3 (eq* 'd4 #f)))
                        (and*
                         (and*
                          (eq* #f (lt* (bv #x07 8) 'in_prop_val_rcvd))
                          (bweq* 'phase (bv #x05 8)))
                         (lt* (bv #x07 8) 'in_prop_bal_rcvd)))
                       (list
                        (<=*
                         'in_prop_val_vals
                         (bwxor*
                          (bwor*
                           (bwxor* (bv #xff 8) 'in_prop_val_vals)
                           (shl* (bv #x01 8) 'in_prop_val_rcvd))
                          (bwxor*
                           (bv #xff 8)
                           (shl* (bool->vect* 'd5) 'in_prop_val_rcvd))))
                        (<=*
                         'in_prop_val_rcvd
                         (add* 'in_prop_val_rcvd (bv #x01 8)))
                        (<=* 'in_prop_bal_vals 'in_prop_bal_vals)
                        (<=* 'in_prop_bal_rcvd 'in_prop_bal_rcvd)
                        (<=* 'd4 'd3))
                       (list
                        (if*
                         (and*
                          (bweq* (bv #x05 8) 'phase)
                          (lt* (bv #x07 8) 'in_prop_val_rcvd))
                         (list
                          (<=* 'phase (bv #x06 8))
                          (<=* 'prop_mval 'in_prop_val_vals)
                          (<=* 'prop_mbal 'in_prop_bal_vals))
                         (list
                          (if*
                           (and*
                            (bweq* 'phase (bv #x06 8))
                            (bweq* 'prom_bal 'prop_mbal))
                           (list
                            (<=* 'phase (bv #x07 8))
                            (<=* 'out_prop_val_vals 'prop_mval)
                            (<=* 'out_prop_val_sent (bv #x00 8))
                            (<=* 'out_prop_bal_vals 'prom_bal)
                            (<=* 'out_prop_bal_sent (bv #x00 8))
                            (<=* 'value 'prop_mval)
                            (<=* 'ballot 'prom_bal))
                           (list
                            (if*
                             (and*
                              (and*
                               (bweq* 'phase (bv #x07 8))
                               (eq* #f (lt* (bv #x07 8) 'out_prop_bal_sent)))
                              (eq* 'd0 'd1))
                             (list
                              (<=* 'out_prop_val_vals 'out_prop_val_vals)
                              (<=* 'out_prop_val_sent 'out_prop_val_sent)
                              (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                              (<=*
                               'out_prop_bal_sent
                               (add* 'out_prop_bal_sent (bv #x01 8)))
                              (<=*
                               'd2
                               (eq*
                                #f
                                (eq*
                                 (bwand*
                                  (bv #x01 8)
                                  (shr* 'out_prop_bal_vals 'out_prop_bal_sent))
                                 (bv #x00 8))))
                              (<=* 'd0 (eq* 'd1 #f)))
                             (list
                              (if*
                               (and*
                                (and*
                                 (and*
                                  (bweq* 'phase (bv #x07 8))
                                  (eq*
                                   #f
                                   (lt* (bv #x07 8) 'out_prop_val_sent)))
                                 (lt* (bv #x07 8) 'out_prop_bal_sent))
                                (eq* 'd1 'd0))
                               (list
                                (<=* 'out_prop_val_vals 'out_prop_val_vals)
                                (<=*
                                 'out_prop_val_sent
                                 (add* (bv #x01 8) 'out_prop_val_sent))
                                (<=* 'out_prop_bal_vals 'out_prop_bal_vals)
                                (<=* 'out_prop_bal_sent 'out_prop_bal_sent)
                                (<=*
                                 'd2
                                 (eq*
                                  (bv #x00 8)
                                  (bwand*
                                   (shl* (bv #x01 8) 'out_prop_val_sent)
                                   (bwxor* 'out_prop_val_vals (bv #xff 8)))))
                                (<=* 'd0 (eq* 'd1 #f)))
                               (list
                                (if*
                                 (and*
                                  (lt* (bv #x07 8) 'out_prop_val_sent)
                                  (bweq* 'phase (bv #x07 8)))
                                 (list (<=* 'phase (bv #x00 8)))
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
;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)])
;;    synthesized-module))

;; cpu time: 965423 real time: 7357224 gc time: 587507
;; (time
;;  (let* ([prog proposer]
;;         [synthesized-module (unity-prog->verilog-module prog 'proposer)])
;;    synthesized-module))

;; (time
;;  (let* ([prog acceptor]
;;         [synthesized-module (unity-prog->verilog-module prog 'acceptor)]
;;         [verifier-results (verify-verilog-module prog synthesized-module)])
;;    (if (verify-ok? verifier-results)
;;        (print-verilog-module synthesized-module)
;;        verifier-results)))
