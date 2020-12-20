#lang rosette/safe

(require "paxos.rkt"
         "synth.rkt"
         "arduino/synth.rkt")

(define proposer-impl
  (arduino*
   (setup*
    (list
     (byte* 'ballot)
     (byte* 'value)
     (byte* 'phase)
     (byte* 'a_mbal)
     (byte* 'b_mbal)
     (byte* 'c_mbal)
     (byte* 'a_mval)
     (byte* 'b_mval)
     (byte* 'c_mval)
     (pin-mode* 'd2 'OUTPUT)
     (pin-mode* 'd1 'INPUT)
     (pin-mode* 'd0 'OUTPUT)
     (pin-mode* 'd5 'OUTPUT)
     (pin-mode* 'd4 'INPUT)
     (pin-mode* 'd3 'OUTPUT)
     (pin-mode* 'd8 'OUTPUT)
     (pin-mode* 'd7 'INPUT)
     (pin-mode* 'd6 'OUTPUT)
     (pin-mode* 'd11 'INPUT)
     (pin-mode* 'd10 'OUTPUT)
     (pin-mode* 'd9 'INPUT)
     (pin-mode* 'd14 'INPUT)
     (pin-mode* 'd13 'OUTPUT)
     (pin-mode* 'd12 'INPUT)
     (pin-mode* 'd17 'INPUT)
     (pin-mode* 'd16 'OUTPUT)
     (pin-mode* 'd15 'INPUT)
     (byte* 'out_a_bal_vals)
     (byte* 'out_a_bal_sent)
     (byte* 'out_b_bal_vals)
     (byte* 'out_b_bal_sent)
     (byte* 'out_c_bal_vals)
     (byte* 'out_c_bal_sent)
     (byte* 'out_a_val_vals)
     (byte* 'out_a_val_sent)
     (byte* 'out_b_val_vals)
     (byte* 'out_b_val_sent)
     (byte* 'out_c_val_vals)
     (byte* 'out_c_val_sent)
     (byte* 'in_a_bal_vals)
     (byte* 'in_a_bal_rcvd)
     (byte* 'in_b_bal_vals)
     (byte* 'in_b_bal_rcvd)
     (byte* 'in_c_bal_vals)
     (byte* 'in_c_bal_rcvd)
     (byte* 'in_a_val_vals)
     (byte* 'in_a_val_rcvd)
     (byte* 'in_b_val_vals)
     (byte* 'in_b_val_rcvd)
     (byte* 'in_c_val_vals)
     (byte* 'in_c_val_rcvd)
     (write* 'd3 (read* 'd4))
     (write* 'd0 (read* 'd1))
     (:=* 'phase (bv #x01 8))
     (:=* 'ballot (bv #x01 8))
     (:=* 'value (bv #x20 8))
     (write* 'd6 (read* 'd7))))
   (loop*
    (list
     (if*
      (lt* (bv #xfe 8) 'ballot)
      (list (:=* 'phase (bv #xff 8)))
      (list
       (if*
        (eq* (bv #x01 8) 'phase)
        (list
         (:=* 'out_a_bal_vals 'ballot)
         (:=* 'out_a_bal_sent (bv #x00 8))
         (:=* 'out_c_bal_vals 'ballot)
         (:=* 'out_c_bal_sent (bv #x00 8))
         (:=* 'out_b_bal_vals 'ballot)
         (:=* 'out_b_bal_sent (bv #x00 8))
         (:=* 'phase (bv #x02 8)))
        (list
         (if*
          (and*
           (eq*
            (bv #x00 8)
            (or*
             (bwand* (eq* (read* 'd0) (bv #x00 8)) (read* 'd1))
             (shr* (read* 'd0) (read* 'd1))))
           (shl* (eq* 'phase (bv #x02 8)) 'out_a_bal_sent))
          (list
           (write*
            'd2
            (eq*
             (bv #x00 8)
             (shr*
              (bv #x01 8)
              (bwand* (bv #x01 8) (shr* 'out_a_bal_vals 'out_a_bal_sent)))))
           (write* 'd0 (lt* (read* 'd1) (bv #x01 8)))
           (:=* 'out_a_bal_sent (add* (bv #x01 8) 'out_a_bal_sent)))
          (list
           (if*
            (bwand*
             (eq* (read* 'd4) (read* 'd3))
             (and*
              (shr* (bv #x20 8) (bwand* 'out_b_bal_sent (bv #xf8 8)))
              (eq* (bv #x02 8) 'phase)))
            (list
             (write*
              'd5
              (eq*
               (bv #x00 8)
               (lt*
                (bwand* 'out_b_bal_vals (shl* (bv #x01 8) 'out_b_bal_sent))
                (bv #x01 8))))
             (write* 'd3 (eq* (read* 'd3) (bv #x00 8)))
             (:=* 'out_b_bal_sent (add* (bv #x01 8) 'out_b_bal_sent)))
            (list
             (if*
              (and*
               (eq* (read* 'd7) (read* 'd6))
               (and*
                (shl* (bv #xf7 8) 'out_c_bal_sent)
                (eq* (bv #x02 8) 'phase)))
              (list
               (write*
                'd8
                (shr*
                 (bv #x01 8)
                 (eq*
                  (bv #x00 8)
                  (bwand* (shl* (bv #x01 8) 'out_c_bal_sent) 'out_c_bal_vals))))
               (write* 'd6 (shl* (bv #x80 8) (read* 'd6)))
               (:=* 'out_c_bal_sent (add* 'out_c_bal_sent (bv #x01 8))))
              (list
               (if*
                (and*
                 (and*
                  (bwand* (bv #xf8 8) 'out_b_bal_sent)
                  (and*
                   (bwand* (bv #xf8 8) 'out_c_bal_sent)
                   (eq* (bv #x02 8) 'phase)))
                 (lt* (bv #x07 8) 'out_a_bal_sent))
                (list
                 (:=* 'in_b_val_vals (bv #x00 8))
                 (:=* 'in_b_val_rcvd (bv #x00 8))
                 (:=* 'in_a_bal_vals (bv #x00 8))
                 (:=* 'in_a_bal_rcvd (bv #x00 8))
                 (:=* 'in_c_bal_vals (bv #x00 8))
                 (:=* 'in_c_bal_rcvd (bv #x00 8))
                 (:=* 'phase (bv #x03 8))
                 (:=* 'in_b_bal_vals (bv #x00 8))
                 (:=* 'in_b_bal_rcvd (bv #x00 8))
                 (:=* 'in_a_val_vals (bv #x00 8))
                 (:=* 'in_a_val_rcvd (bv #x00 8))
                 (:=* 'in_c_val_vals (bv #x00 8))
                 (:=* 'in_c_val_rcvd (bv #x00 8)))
                (list
                 (if*
                  (and*
                   (shl* (eq* (bv #x03 8) 'phase) 'in_a_bal_rcvd)
                   (bwxor* (read* 'd9) (read* 'd10)))
                  (list
                   (:=*
                    'in_a_bal_vals
                    (bwxor*
                     (bwxor* (shl* (read* 'd11) 'in_a_bal_rcvd) (bv #xff 8))
                     (bwor*
                      (shl* (bv #x01 8) 'in_a_bal_rcvd)
                      (bwxor* 'in_a_bal_vals (bv #xff 8)))))
                   (:=* 'in_a_bal_rcvd (add* (bv #x01 8) 'in_a_bal_rcvd))
                   (write* 'd10 (read* 'd9)))
                  (list
                   (if*
                    (bwand*
                     (bwor*
                      (bwand* (eq* (read* 'd9) (bv #x00 8)) (read* 'd10))
                      (and* (read* 'd9) (shl* (bv #x80 8) (read* 'd10))))
                     (and*
                      (bwand* 'in_a_bal_rcvd (bv #xf8 8))
                      (and*
                       (eq* (bv #x03 8) 'phase)
                       (lt* (bwand* (bv #xf8 8) 'in_a_val_rcvd) (bv #x02 8)))))
                    (list
                     (:=*
                      'in_a_val_vals
                      (bwxor*
                       (bwor*
                        (bwxor* (bv #xff 8) 'in_a_val_vals)
                        (shl* (bv #x01 8) 'in_a_val_rcvd))
                       (bwxor* (bv #xff 8) (shl* (read* 'd11) 'in_a_val_rcvd))))
                     (:=* 'in_a_val_rcvd (add* 'in_a_val_rcvd (bv #x01 8)))
                     (write* 'd10 (read* 'd9)))
                    (list
                     (if*
                      (and*
                       (bwand*
                        (eq* (bv #x00 8) (bwand* (bv #xf8 8) 'in_b_bal_rcvd))
                        (eq* (bv #x03 8) 'phase))
                       (bwor*
                        (shr* (read* 'd12) (read* 'd13))
                        (shr* (read* 'd13) (read* 'd12))))
                      (list
                       (:=*
                        'in_b_bal_vals
                        (bwxor*
                         (bwxor* (shl* (read* 'd14) 'in_b_bal_rcvd) (bv #xff 8))
                         (bwor*
                          (shl* (bv #x01 8) 'in_b_bal_rcvd)
                          (bwxor* 'in_b_bal_vals (bv #xff 8)))))
                       (:=* 'in_b_bal_rcvd (add* (bv #x01 8) 'in_b_bal_rcvd))
                       (write* 'd13 (read* 'd12)))
                      (list
                       (if*
                        (and*
                         (and*
                          (bwand* (bv #xf8 8) 'in_b_bal_rcvd)
                          (shl* (eq* 'phase (bv #x03 8)) 'in_b_val_rcvd))
                         (bwxor* (read* 'd13) (read* 'd12)))
                        (list
                         (write* 'd13 (read* 'd12))
                         (:=*
                          'in_b_val_vals
                          (bwxor*
                           (bwor*
                            (shl* (bv #x01 8) 'in_b_val_rcvd)
                            (bwxor* 'in_b_val_vals (bv #xff 8)))
                           (bwxor*
                            (bv #xff 8)
                            (shl* (read* 'd14) 'in_b_val_rcvd))))
                         (:=* 'in_b_val_rcvd (add* (bv #x01 8) 'in_b_val_rcvd)))
                        (list
                         (if*
                          (bwand*
                           (bwxor* (read* 'd15) (read* 'd16))
                           (bwand*
                            (lt* (bwand* (bv #xf8 8) 'in_c_bal_rcvd) (bv #x02 8))
                            (eq* (bv #x03 8) 'phase)))
                          (list
                           (:=*
                            'in_c_bal_vals
                            (bwxor*
                             (bwor*
                              (shl* (bv #x01 8) 'in_c_bal_rcvd)
                              (bwxor* 'in_c_bal_vals (bv #xff 8)))
                             (bwxor*
                              (bv #xff 8)
                              (shl* (read* 'd17) 'in_c_bal_rcvd))))
                           (:=* 'in_c_bal_rcvd (add* 'in_c_bal_rcvd (bv #x01 8)))
                           (write* 'd16 (read* 'd15)))
                          (list
                           (if*
                            (bwand*
                             (and*
                              (bwand*
                               (lt*
                                (bwand* (bv #xf8 8) 'in_c_val_rcvd)
                                (bv #x02 8))
                               (eq* (bv #x03 8) 'phase))
                              (bwand* 'in_c_bal_rcvd (bv #xf8 8)))
                             (bwor*
                              (bwand*
                               (eq* (read* 'd15) (bv #x00 8))
                               (read* 'd16))
                              (and*
                               (eq* (read* 'd16) (bv #x00 8))
                               (read* 'd15))))
                            (list
                             (write* 'd16 (read* 'd15))
                             (:=*
                              'in_c_val_vals
                              (bwxor*
                               (bwor*
                                (bwxor* (bv #xff 8) 'in_c_val_vals)
                                (shl* (bv #x01 8) 'in_c_val_rcvd))
                               (bwxor*
                                (shl* (read* 'd17) 'in_c_val_rcvd)
                                (bv #xff 8))))
                             (:=*
                              'in_c_val_rcvd
                              (add* (bv #x01 8) 'in_c_val_rcvd)))
                            (list
                             (if*
                              (and*
                               (bwand* (bv #xf8 8) 'in_a_val_rcvd)
                               (and*
                                (and*
                                 (eq* (bv #x03 8) 'phase)
                                 (shr* 'in_c_val_rcvd (bv #x03 8)))
                                (shr* 'in_b_val_rcvd (bv #x03 8))))
                              (list
                               (:=* 'b_mbal 'in_b_bal_vals)
                               (:=* 'a_mval 'in_a_val_vals)
                               (:=* 'c_mval 'in_c_val_vals)
                               (:=* 'c_mbal 'in_c_bal_vals)
                               (:=* 'phase (bv #x04 8))
                               (:=* 'a_mbal 'in_a_bal_vals)
                               (:=* 'b_mval 'in_b_val_vals))
                              (list
                               (if*
                                (shr*
                                 (shr*
                                  (lt* 'c_mbal (eq* (bv #x04 8) 'phase))
                                  'b_mbal)
                                 'a_mbal)
                                (list (:=* 'phase (bv #x05 8)))
                                (list
                                 (if*
                                  (bwand*
                                   (bwor*
                                    (lt* 'b_mbal 'a_mbal)
                                    (eq* 'a_mbal 'b_mbal))
                                   (and*
                                    (eq* (bv #x04 8) 'phase)
                                    (bwxor*
                                     (lt* 'c_mbal 'a_mbal)
                                     (eq* 'c_mbal 'a_mbal))))
                                  (list
                                   (:=* 'value 'a_mval)
                                   (:=* 'phase (bv #x05 8)))
                                  (list
                                   (if*
                                    (and*
                                     (bwxor*
                                      (eq* 'c_mbal 'b_mbal)
                                      (lt* 'c_mbal 'b_mbal))
                                     (eq* (bv #x04 8) 'phase))
                                    (list
                                     (:=* 'value 'b_mval)
                                     (:=* 'phase (bv #x05 8)))
                                    (list
                                     (if*
                                      (eq* (bv #x04 8) 'phase)
                                      (list
                                       (:=* 'value 'c_mval)
                                       (:=* 'phase (bv #x05 8)))
                                      (list
                                       (if*
                                        (eq* 'phase (bv #x05 8))
                                        (list
                                         (:=* 'out_c_bal_vals 'ballot)
                                         (:=* 'out_c_bal_sent (bv #x00 8))
                                         (:=* 'out_c_val_vals 'value)
                                         (:=* 'out_c_val_sent (bv #x00 8))
                                         (:=* 'out_a_bal_vals 'ballot)
                                         (:=* 'out_a_bal_sent (bv #x00 8))
                                         (:=* 'out_a_val_vals 'value)
                                         (:=* 'out_a_val_sent (bv #x00 8))
                                         (:=* 'out_b_val_vals 'value)
                                         (:=* 'out_b_val_sent (bv #x00 8))
                                         (:=* 'out_b_bal_vals 'ballot)
                                         (:=* 'out_b_bal_sent (bv #x00 8))
                                         (:=* 'phase (bv #x06 8)))
                                        (list
                                         (if*
                                          (bwand*
                                           (and*
                                            (shl* (bv #x01 8) 'out_a_bal_sent)
                                            (eq* (bv #x06 8) 'phase))
                                           (eq* (read* 'd1) (read* 'd0)))
                                          (list
                                           (write*
                                            'd2
                                            (bwxor*
                                             (bv #x01 8)
                                             (shr*
                                              (bv #x01 8)
                                              (bwand*
                                               (shl* (bv #x01 8) 'out_a_bal_sent)
                                               'out_a_bal_vals))))
                                           (write*
                                            'd0
                                            (eq* (read* 'd0) (bv #x00 8)))
                                           (:=*
                                            'out_a_bal_sent
                                            (add* 'out_a_bal_sent (bv #x01 8))))
                                          (list
                                           (if*
                                            (bwand*
                                             (and*
                                              (and*
                                               (shr* (bv #xb6 8) 'out_a_val_sent)
                                               (eq* 'phase (bv #x06 8)))
                                              (bwand*
                                               (bv #xf8 8)
                                               'out_a_bal_sent))
                                             (eq* (read* 'd1) (read* 'd0)))
                                            (list
                                             (write*
                                              'd2
                                              (bwxor*
                                               (shr*
                                                (bv #x01 8)
                                                (bwand*
                                                 (bv #x01 8)
                                                 (shr*
                                                  'out_a_val_vals
                                                  'out_a_val_sent)))
                                               (bv #x01 8)))
                                             (write*
                                              'd0
                                              (eq* (read* 'd0) (bv #x00 8)))
                                             (:=*
                                              'out_a_val_sent
                                              (add*
                                               (bv #x01 8)
                                               'out_a_val_sent)))
                                            (list
                                             (if*
                                              (and*
                                               (bwand*
                                                (lt*
                                                 (bwand*
                                                  (bv #xf8 8)
                                                  'out_b_bal_sent)
                                                 (bv #x02 8))
                                                (eq* (bv #x06 8) 'phase))
                                               (eq* (read* 'd3) (read* 'd4)))
                                              (list
                                               (write*
                                                'd5
                                                (eq*
                                                 (bv #x00 8)
                                                 (eq*
                                                  (bv #x00 8)
                                                  (bwand*
                                                   'out_b_bal_vals
                                                   (shl*
                                                    (bv #x01 8)
                                                    'out_b_bal_sent)))))
                                               (write*
                                                'd3
                                                (eq* (read* 'd3) (bv #x00 8)))
                                               (:=*
                                                'out_b_bal_sent
                                                (add*
                                                 (bv #x01 8)
                                                 'out_b_bal_sent)))
                                              (list
                                               (if*
                                                (and*
                                                 (and*
                                                  (lt*
                                                   (bv #x07 8)
                                                   'out_b_bal_sent)
                                                  (and*
                                                   (eq* 'phase (bv #x06 8))
                                                   (lt*
                                                    (bwand*
                                                     (bv #xf8 8)
                                                     'out_b_val_sent)
                                                    (bv #x02 8))))
                                                 (eq* (read* 'd4) (read* 'd3)))
                                                (list
                                                 (write*
                                                  'd5
                                                  (eq*
                                                   (bv #x00 8)
                                                   (shr*
                                                    (bv #x01 8)
                                                    (bwand*
                                                     (shr*
                                                      'out_b_val_vals
                                                      'out_b_val_sent)
                                                     (bv #x01 8)))))
                                                 (write*
                                                  'd3
                                                  (eq* (read* 'd3) (bv #x00 8)))
                                                 (:=*
                                                  'out_b_val_sent
                                                  (add*
                                                   (bv #x01 8)
                                                   'out_b_val_sent)))
                                                (list
                                                 (if*
                                                  (bwand*
                                                   (eq* (read* 'd6) (read* 'd7))
                                                   (and*
                                                    (shl*
                                                     (bv #x25 8)
                                                     'out_c_bal_sent)
                                                    (eq* (bv #x06 8) 'phase)))
                                                  (list
                                                   (write*
                                                    'd8
                                                    (bwxor*
                                                     (shr*
                                                      (bv #x01 8)
                                                      (bwand*
                                                       (bv #x01 8)
                                                       (shr*
                                                        'out_c_bal_vals
                                                        'out_c_bal_sent)))
                                                     (bv #x01 8)))
                                                   (write*
                                                    'd6
                                                    (eq*
                                                     (read* 'd7)
                                                     (bv #x00 8)))
                                                   (:=*
                                                    'out_c_bal_sent
                                                    (add*
                                                     (bv #x01 8)
                                                     'out_c_bal_sent)))
                                                  (list
                                                   (if*
                                                    (bwand*
                                                     (eq*
                                                      (bv #x00 8)
                                                      (bwxor*
                                                       (read* 'd7)
                                                       (read* 'd6)))
                                                     (and*
                                                      (bwand*
                                                       (lt*
                                                        (bwand*
                                                         (bv #xf8 8)
                                                         'out_c_val_sent)
                                                        (bv #x02 8))
                                                       (eq* 'phase (bv #x06 8)))
                                                      (shr*
                                                       'out_c_bal_sent
                                                       (bv #x03 8))))
                                                    (list
                                                     (write*
                                                      'd8
                                                      (lt*
                                                       (shr*
                                                        (bv #x01 8)
                                                        (bwand*
                                                         (shl*
                                                          (bv #x01 8)
                                                          'out_c_val_sent)
                                                         'out_c_val_vals))
                                                       (bv #x01 8)))
                                                     (write*
                                                      'd6
                                                      (eq*
                                                       (read* 'd6)
                                                       (bv #x00 8)))
                                                     (:=*
                                                      'out_c_val_sent
                                                      (add*
                                                       (bv #x01 8)
                                                       'out_c_val_sent)))
                                                    (list
                                                     (if*
                                                      (and*
                                                       (and*
                                                        (bwand*
                                                         (bv #xf8 8)
                                                         'out_b_val_sent)
                                                        (and*
                                                         (eq* (bv #x06 8) 'phase)
                                                         (bwand*
                                                          (bv #xf8 8)
                                                          'out_c_val_sent)))
                                                       (bwand*
                                                        (bv #xf8 8)
                                                        'out_a_val_sent))
                                                      (list
                                                       (:=*
                                                        'in_c_bal_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_c_bal_rcvd
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_b_bal_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_b_bal_rcvd
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_b_val_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_b_val_rcvd
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_a_bal_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_a_bal_rcvd
                                                        (bv #x00 8))
                                                       (:=* 'phase (bv #x07 8))
                                                       (:=*
                                                        'in_a_val_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_a_val_rcvd
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_c_val_vals
                                                        (bv #x00 8))
                                                       (:=*
                                                        'in_c_val_rcvd
                                                        (bv #x00 8)))
                                                      (list
                                                       (if*
                                                        (and*
                                                         (shl*
                                                          (eq*
                                                           'phase
                                                           (bv #x07 8))
                                                          'in_a_bal_rcvd)
                                                         (bwor*
                                                          (bwand*
                                                           (read* 'd10)
                                                           (bwxor*
                                                            (bv #x01 8)
                                                            (read* 'd9)))
                                                          (lt*
                                                           (read* 'd10)
                                                           (read* 'd9))))
                                                        (list
                                                         (:=*
                                                          'in_a_bal_vals
                                                          (bwxor*
                                                           (bwor*
                                                            (bwxor*
                                                             'in_a_bal_vals
                                                             (bv #xff 8))
                                                            (shl*
                                                             (bv #x01 8)
                                                             'in_a_bal_rcvd))
                                                           (bwxor*
                                                            (shl*
                                                             (read* 'd11)
                                                             'in_a_bal_rcvd)
                                                            (bv #xff 8))))
                                                         (:=*
                                                          'in_a_bal_rcvd
                                                          (add*
                                                           (bv #x01 8)
                                                           'in_a_bal_rcvd))
                                                         (write*
                                                          'd10
                                                          (read* 'd9)))
                                                        (list
                                                         (if*
                                                          (and*
                                                           (bwxor*
                                                            (read* 'd10)
                                                            (read* 'd9))
                                                           (and*
                                                            (shl*
                                                             (eq*
                                                              (bv #x07 8)
                                                              'phase)
                                                             'in_a_val_rcvd)
                                                            (bwand*
                                                             (bv #xf8 8)
                                                             'in_a_bal_rcvd)))
                                                          (list
                                                           (write*
                                                            'd10
                                                            (read* 'd9))
                                                           (:=*
                                                            'in_a_val_vals
                                                            (bwxor*
                                                             (bwor*
                                                              (shl*
                                                               (bv #x01 8)
                                                               'in_a_val_rcvd)
                                                              (bwxor*
                                                               (bv #xff 8)
                                                               'in_a_val_vals))
                                                             (bwxor*
                                                              (shl*
                                                               (read* 'd11)
                                                               'in_a_val_rcvd)
                                                              (bv #xff 8))))
                                                           (:=*
                                                            'in_a_val_rcvd
                                                            (bwxor*
                                                             (bv #xff 8)
                                                             (add*
                                                              (bwxor*
                                                               'in_a_val_rcvd
                                                               (bv #xff 8))
                                                              (bv #xff 8)))))
                                                          (list
                                                           (if*
                                                            (and*
                                                             (bwxor*
                                                              (read* 'd12)
                                                              (read* 'd13))
                                                             (shl*
                                                              (eq*
                                                               'phase
                                                               (bv #x07 8))
                                                              'in_b_bal_rcvd))
                                                            (list
                                                             (write*
                                                              'd13
                                                              (read* 'd12))
                                                             (:=*
                                                              'in_b_bal_vals
                                                              (bwxor*
                                                               (bwor*
                                                                (shl*
                                                                 (bv #x01 8)
                                                                 'in_b_bal_rcvd)
                                                                (bwxor*
                                                                 (bv #xff 8)
                                                                 'in_b_bal_vals))
                                                               (bwxor*
                                                                (shl*
                                                                 (read* 'd14)
                                                                 'in_b_bal_rcvd)
                                                                (bv #xff 8))))
                                                             (:=*
                                                              'in_b_bal_rcvd
                                                              (add*
                                                               'in_b_bal_rcvd
                                                               (bv #x01 8))))
                                                            (list
                                                             (if*
                                                              (bwand*
                                                               (bwxor*
                                                                (read* 'd12)
                                                                (read* 'd13))
                                                               (and*
                                                                (bwand*
                                                                 (bv #xf8 8)
                                                                 'in_b_bal_rcvd)
                                                                (shl*
                                                                 (eq*
                                                                  'phase
                                                                  (bv #x07 8))
                                                                 'in_b_val_rcvd)))
                                                              (list
                                                               (write*
                                                                'd13
                                                                (read* 'd12))
                                                               (:=*
                                                                'in_b_val_vals
                                                                (bwxor*
                                                                 (bwxor*
                                                                  (shl*
                                                                   (read* 'd14)
                                                                   'in_b_val_rcvd)
                                                                  (bv #xff 8))
                                                                 (bwor*
                                                                  (shl*
                                                                   (bv #x01 8)
                                                                   'in_b_val_rcvd)
                                                                  (bwxor*
                                                                   'in_b_val_vals
                                                                   (bv #xff 8)))))
                                                               (:=*
                                                                'in_b_val_rcvd
                                                                (add*
                                                                 (bv #x01 8)
                                                                 'in_b_val_rcvd)))
                                                              (list
                                                               (if*
                                                                (bwand*
                                                                 (bwand*
                                                                  (eq*
                                                                   (bv #x07 8)
                                                                   'phase)
                                                                  (eq*
                                                                   (bv #x00 8)
                                                                   (bwand*
                                                                    'in_c_bal_rcvd
                                                                    (bv #xf8 8))))
                                                                 (bwxor*
                                                                  (read* 'd15)
                                                                  (read* 'd16)))
                                                                (list
                                                                 (:=*
                                                                  'in_c_bal_vals
                                                                  (bwxor*
                                                                   (bwor*
                                                                    (shl*
                                                                     (bv #x01 8)
                                                                     'in_c_bal_rcvd)
                                                                    'in_c_bal_vals)
                                                                   (shl*
                                                                    (shr*
                                                                     (bv #x01 8)
                                                                     (read*
                                                                      'd17))
                                                                    'in_c_bal_rcvd)))
                                                                 (:=*
                                                                  'in_c_bal_rcvd
                                                                  (add*
                                                                   'in_c_bal_rcvd
                                                                   (bv #x01 8)))
                                                                 (write*
                                                                  'd16
                                                                  (read* 'd15)))
                                                                (list
                                                                 (if*
                                                                  (bwand*
                                                                   (and*
                                                                    (bwand*
                                                                     (bv #xf8 8)
                                                                     'in_c_bal_rcvd)
                                                                    (and*
                                                                     (shl*
                                                                      (bv #x4d 8)
                                                                      'in_c_val_rcvd)
                                                                     (eq*
                                                                      (bv #x07 8)
                                                                      'phase)))
                                                                   (bwxor*
                                                                    (read* 'd16)
                                                                    (read*
                                                                     'd15)))
                                                                  (list
                                                                   (:=*
                                                                    'in_c_val_vals
                                                                    (bwxor*
                                                                     (shl*
                                                                      (shr*
                                                                       (bv #x01 8)
                                                                       (read*
                                                                        'd17))
                                                                      'in_c_val_rcvd)
                                                                     (bwor*
                                                                      'in_c_val_vals
                                                                      (shl*
                                                                       (bv #x01 8)
                                                                       'in_c_val_rcvd))))
                                                                   (:=*
                                                                    'in_c_val_rcvd
                                                                    (add*
                                                                     (bv #x01 8)
                                                                     'in_c_val_rcvd))
                                                                   (write*
                                                                    'd16
                                                                    (read*
                                                                     'd15)))
                                                                  (list
                                                                   (if*
                                                                    (and*
                                                                     (bwand*
                                                                      (bv #xf8 8)
                                                                      'in_a_val_rcvd)
                                                                     (and*
                                                                      (and*
                                                                       (bwand*
                                                                        (bv #xf8 8)
                                                                        'in_c_val_rcvd)
                                                                       (eq*
                                                                        (bv #x07 8)
                                                                        'phase))
                                                                      (bwand*
                                                                       (bv #xf8 8)
                                                                       'in_b_val_rcvd)))
                                                                    (list
                                                                     (:=*
                                                                      'b_mbal
                                                                      'in_b_bal_vals)
                                                                     (:=*
                                                                      'b_mval
                                                                      'in_b_val_vals)
                                                                     (:=*
                                                                      'c_mbal
                                                                      'in_c_bal_vals)
                                                                     (:=*
                                                                      'a_mbal
                                                                      'in_a_bal_vals)
                                                                     (:=*
                                                                      'phase
                                                                      (bv #x08 8))
                                                                     (:=*
                                                                      'a_mval
                                                                      'in_a_val_vals)
                                                                     (:=*
                                                                      'c_mval
                                                                      'in_c_val_vals))
                                                                    (list
                                                                     (if*
                                                                      (and*
                                                                       (bwand*
                                                                        (bwand*
                                                                         (eq*
                                                                          'phase
                                                                          (bv #x08 8))
                                                                         (eq*
                                                                          'value
                                                                          'c_mval))
                                                                        (eq*
                                                                         'value
                                                                         'b_mval))
                                                                       (eq*
                                                                        'value
                                                                        'a_mval))
                                                                      (list
                                                                       (:=*
                                                                        'phase
                                                                        (bv #x00 8)))
                                                                      (list
                                                                       (if*
                                                                        (eq*
                                                                         (bv #x08 8)
                                                                         'phase)
                                                                        (list
                                                                         (:=*
                                                                          'phase
                                                                          (bv #xff 8)))
                                                                        '())))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

(define acceptor-impl
  (arduino*
   (setup*
    (list
     (byte* 'ballot)
     (byte* 'value)
     (byte* 'phase)
     (byte* 'prom_bal)
     (byte* 'prop_mbal)
     (byte* 'prop_mval)
     (pin-mode* 'd2 'OUTPUT)
     (pin-mode* 'd1 'INPUT)
     (pin-mode* 'd0 'OUTPUT)
     (pin-mode* 'd5 'INPUT)
     (pin-mode* 'd4 'OUTPUT)
     (pin-mode* 'd3 'INPUT)
     (byte* 'out_prop_bal_vals)
     (byte* 'out_prop_bal_sent)
     (byte* 'out_prop_val_vals)
     (byte* 'out_prop_val_sent)
     (byte* 'in_prop_bal_vals)
     (byte* 'in_prop_bal_rcvd)
     (byte* 'in_prop_val_vals)
     (byte* 'in_prop_val_rcvd)
     (:=* 'ballot (bv #x00 8))
     (:=* 'value (bv #x00 8))
     (:=* 'in_prop_bal_vals (bv #x00 8))
     (:=* 'in_prop_bal_rcvd (bv #x00 8))
     (:=* 'prom_bal (bv #x00 8))
     (:=* 'phase (bv #x01 8))
     (write* 'd0 (read* 'd1))))
   (loop*
    (list
     (if*
      (eq* (bv #x01 8) 'phase)
      (list
       (:=* 'in_prop_bal_vals (bv #x00 8))
       (:=* 'in_prop_bal_rcvd (bv #x00 8))
       (:=* 'phase (bv #x02 8)))
      (list
       (if*
        (and*
         (bwxor* (read* 'd4) (read* 'd3))
         (shl* (eq* 'phase (bv #x02 8)) 'in_prop_bal_rcvd))
        (list
         (:=*
          'in_prop_bal_vals
          (bwxor*
           (shl* (eq* (bv #x00 8) (read* 'd5)) 'in_prop_bal_rcvd)
           (bwor* (shl* (bv #x01 8) 'in_prop_bal_rcvd) 'in_prop_bal_vals)))
         (:=* 'in_prop_bal_rcvd (add* (bv #x01 8) 'in_prop_bal_rcvd))
         (write* 'd4 (read* 'd3)))
        (list
         (if*
          (and* (eq* 'phase (bv #x02 8)) (shr* 'in_prop_bal_rcvd (bv #x03 8)))
          (list (:=* 'prop_mbal 'in_prop_bal_vals) (:=* 'phase (bv #x03 8)))
          (list
           (if*
            (and*
             (lt* 'ballot 'prop_mbal)
             (and* (eq* (bv #x03 8) 'phase) (lt* 'prom_bal 'prop_mbal)))
            (list
             (:=* 'phase (bv #x04 8))
             (:=* 'prom_bal 'prop_mbal)
             (:=* 'out_prop_bal_vals 'ballot)
             (:=* 'out_prop_bal_sent (bv #x00 8))
             (:=* 'out_prop_val_vals 'value)
             (:=* 'out_prop_val_sent (bv #x00 8)))
            (list
             (if*
              (and*
               (shl* (eq* (bv #x04 8) 'phase) 'out_prop_bal_sent)
               (eq* (read* 'd1) (read* 'd0)))
              (list
               (write*
                'd2
                (shr*
                 (bv #x01 8)
                 (eq*
                  (bwand*
                   (shr* 'out_prop_bal_vals 'out_prop_bal_sent)
                   (bv #x01 8))
                  (bv #x00 8))))
               (write* 'd0 (eq* (read* 'd1) (bv #x00 8)))
               (:=* 'out_prop_bal_sent (add* (bv #x01 8) 'out_prop_bal_sent)))
              (list
               (if*
                (bwand*
                 (eq* (read* 'd1) (read* 'd0))
                 (and*
                  (shl* (eq* (bv #x04 8) 'phase) 'out_prop_val_sent)
                  (shr* 'out_prop_bal_sent (bv #x03 8))))
                (list
                 (write*
                  'd2
                  (bwxor*
                   (bv #x01 8)
                   (eq*
                    (bv #x00 8)
                    (bwand*
                     'out_prop_val_vals
                     (shl* (bv #x01 8) 'out_prop_val_sent)))))
                 (write* 'd0 (eq* (read* 'd1) (bv #x00 8)))
                 (:=* 'out_prop_val_sent (add* (bv #x01 8) 'out_prop_val_sent)))
                (list
                 (if*
                  (bwand*
                   (eq* (bv #x04 8) 'phase)
                   (lt* (bv #x07 8) 'out_prop_val_sent))
                  (list
                   (:=* 'in_prop_bal_vals (bv #x00 8))
                   (:=* 'in_prop_bal_rcvd (bv #x00 8))
                   (:=* 'phase (bv #x05 8))
                   (:=* 'in_prop_val_vals (bv #x00 8))
                   (:=* 'in_prop_val_rcvd (bv #x00 8)))
                  (list
                   (if*
                    (and*
                     (add*
                      (shr* (read* 'd3) (read* 'd4))
                      (bwand* (eq* (read* 'd3) (bv #x00 8)) (read* 'd4)))
                     (shl* (eq* 'phase (bv #x05 8)) 'in_prop_bal_rcvd))
                    (list
                     (:=*
                      'in_prop_bal_vals
                      (bwxor*
                       (bwxor* (shl* (read* 'd5) 'in_prop_bal_rcvd) (bv #xff 8))
                       (bwor*
                        (shl* (bv #x01 8) 'in_prop_bal_rcvd)
                        (bwxor* 'in_prop_bal_vals (bv #xff 8)))))
                     (:=* 'in_prop_bal_rcvd (add* 'in_prop_bal_rcvd (bv #x01 8)))
                     (write* 'd4 (read* 'd3)))
                    (list
                     (if*
                      (bwand*
                       (bwor*
                        (and* (read* 'd4) (shl* (bv #x80 8) (read* 'd3)))
                        (lt* (read* 'd4) (read* 'd3)))
                       (and*
                        (bwand* (bv #xf8 8) 'in_prop_bal_rcvd)
                        (bwand*
                         (eq* (bv #x05 8) 'phase)
                         (eq*
                          (bv #x00 8)
                          (bwand* (bv #xf8 8) 'in_prop_val_rcvd)))))
                      (list
                       (write* 'd4 (read* 'd3))
                       (:=*
                        'in_prop_val_vals
                        (bwxor*
                         (bwor*
                          (shl* (bv #x01 8) 'in_prop_val_rcvd)
                          'in_prop_val_vals)
                         (shl*
                          (shr* (bv #x01 8) (read* 'd5))
                          (shr* 'in_prop_val_rcvd (read* 'd5)))))
                       (:=*
                        'in_prop_val_rcvd
                        (add* (bv #x01 8) 'in_prop_val_rcvd)))
                      (list
                       (if*
                        (and*
                         (shr* 'in_prop_val_rcvd (bv #x03 8))
                         (eq* (bv #x05 8) 'phase))
                        (list
                         (:=* 'prop_mbal 'in_prop_bal_vals)
                         (:=* 'prop_mval 'in_prop_val_vals)
                         (:=* 'phase (bv #x06 8)))
                        (list
                         (if*
                          (bwand*
                           (eq* 'prop_mbal 'prom_bal)
                           (eq* 'phase (bv #x06 8)))
                          (list
                           (:=* 'out_prop_val_vals 'prop_mval)
                           (:=* 'out_prop_val_sent (bv #x00 8))
                           (:=* 'value 'prop_mval)
                           (:=* 'ballot 'prop_mbal)
                           (:=* 'phase (bv #x07 8))
                           (:=* 'out_prop_bal_vals 'prop_mbal)
                           (:=* 'out_prop_bal_sent (bv #x00 8)))
                          (list
                           (if*
                            (and*
                             (and*
                              (add*
                               (lt* (bv #x07 8) 'out_prop_bal_sent)
                               (bv #xff 8))
                              (eq* 'phase (bv #x07 8)))
                             (eq* (read* 'd1) (read* 'd0)))
                            (list
                             (write*
                              'd2
                              (shr*
                               (bv #x01 8)
                               (shr*
                                (bv #x01 8)
                                (bwand*
                                 'out_prop_bal_vals
                                 (shl* (bv #x01 8) 'out_prop_bal_sent)))))
                             (write* 'd0 (eq* (read* 'd0) (bv #x00 8)))
                             (:=*
                              'out_prop_bal_sent
                              (add* (bv #x01 8) 'out_prop_bal_sent)))
                            (list
                             (if*
                              (bwand*
                               (and*
                                (bwand*
                                 (eq* 'phase (bv #x07 8))
                                 (lt*
                                  (bwand* (bv #xf8 8) 'out_prop_val_sent)
                                  (bv #x02 8)))
                                (bwand* 'out_prop_bal_sent (bv #xf8 8)))
                               (eq* (read* 'd1) (read* 'd0)))
                              (list
                               (write*
                                'd2
                                (bwxor*
                                 (bv #x01 8)
                                 (lt*
                                  (bwand*
                                   'out_prop_val_vals
                                   (shl* (bv #x01 8) 'out_prop_val_sent))
                                  (bv #x01 8))))
                               (write* 'd0 (shl* (bv #x80 8) (read* 'd0)))
                               (:=*
                                'out_prop_val_sent
                                (add* 'out_prop_val_sent (bv #x01 8))))
                              (list
                               (if*
                                (and*
                                 (shr* 'out_prop_val_sent (bv #x03 8))
                                 (eq* 'phase (bv #x07 8)))
                                (list (:=* 'phase (bv #x00 8)))
                                '())))))))))))))))))))))))))))))))

(current-bitwidth 9)

;; (print-arduino-program proposer-impl)

;; (print-arduino-program acceptor-impl)

;; cpu time: 435624 real time: 2756502 gc time: 125570
;; cpu time: 362027 real time: 4071985 gc time: 85534
;; (time
;;  (unity-prog->arduino-prog proposer))

;; cpu time: 54464 real time: 714941 gc time: 5057
;; cpu time: 51846 real time: 1113980 gc time: 4697
;; (time
;;  (unity-prog->arduino-prog acceptor))

(time
 (unity-prog->arduino-prog mini-test))
