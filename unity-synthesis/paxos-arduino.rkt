#lang rosette/safe

(require "config.rkt"
         "paxos.rkt"
         "synth.rkt"
         "arduino/backend.rkt"
         "arduino/mapping.rkt"
         "arduino/semantics.rkt"
         "arduino/syntax.rkt"
         "arduino/synth.rkt"
         "arduino/verify.rkt")

(define acceptor-impl
   (arduino*
  (setup*
   (list
    (unsigned-int* 'ballot)
    (unsigned-int* 'value)
    (unsigned-int* 'phase)
    (unsigned-int* 'prom_bal)
    (unsigned-int* 'prop_mbal)
    (unsigned-int* 'prop_mval)
    (pin-mode* 'd2 'OUTPUT)
    (pin-mode* 'd1 'INPUT)
    (pin-mode* 'd0 'OUTPUT)
    (pin-mode* 'd5 'INPUT)
    (pin-mode* 'd4 'OUTPUT)
    (pin-mode* 'd3 'INPUT)
    (unsigned-int* 'out_prop_bal_vals)
    (unsigned-int* 'out_prop_bal_sent)
    (unsigned-int* 'out_prop_val_vals)
    (unsigned-int* 'out_prop_val_sent)
    (unsigned-int* 'in_prop_bal_vals)
    (unsigned-int* 'in_prop_bal_rcvd)
    (unsigned-int* 'in_prop_val_vals)
    (unsigned-int* 'in_prop_val_rcvd)
    (:=* 'ballot (bv #x00000000 32))
    (:=* 'value (bv #x00000000 32))
    (:=* 'phase (bv #x00000001 32))
    (:=* 'prom_bal (bv #x00000000 32))
    (:=* 'in_prop_bal_rcvd (bv #x00000000 32))
    (:=* 'in_prop_bal_vals (bv #x00000000 32))))
  (loop*
   (list
    (if*
     (eq* 'phase (bv #x00000001 32))
     (list
      (:=* 'in_prop_bal_rcvd (bv #x00000000 32))
      (:=* 'in_prop_bal_vals (bv #x00000000 32))
      (:=* 'phase (bv #x00000002 32)))
     (list
      (if*
       (and*
        (bwand*
         (shr*
          (bv #x80004803 32)
          (bwand* 'in_prop_bal_rcvd (bv #xffffffe0 32)))
         (eq* 'phase (bv #x00000002 32)))
        (bwxor* (read* 'd4) (read* 'd3)))
       (list
        (:=*
         'in_prop_bal_vals
         (bwxor*
          (bwxor* 'in_prop_bal_vals (shl* (read* 'd5) 'in_prop_bal_rcvd))
          (bwand*
           'in_prop_bal_vals
           (shl* (bv #x00000001 32) 'in_prop_bal_rcvd))))
        (:=* 'in_prop_bal_rcvd (add* (bv #x00000001 32) 'in_prop_bal_rcvd))
        (write* 'd4 (read* 'd3)))
       (list
        (if*
         (and*
          (bwand* 'in_prop_bal_rcvd (bv #xffffffe0 32))
          (eq* (bv #x00000002 32) 'phase))
         (list
          (:=* 'prop_mbal 'in_prop_bal_vals)
          (:=* 'phase (bv #x00000003 32)))
         (list
          (if*
           (bwand*
            (bwand* (lt* 'prom_bal 'prop_mbal) (eq* (bv #x00000003 32) 'phase))
            (lt* 'ballot 'prop_mbal))
           (list
            (:=* 'out_prop_bal_sent (bv #x00000000 32))
            (:=* 'out_prop_bal_vals 'ballot)
            (:=* 'out_prop_val_sent (bv #x00000000 32))
            (:=* 'out_prop_val_vals 'value)
            (:=* 'prom_bal 'prop_mbal)
            (:=* 'phase (bv #x00000004 32)))
           (list
            (if*
             (and*
              (eq* (bwxor* (read* 'd1) (read* 'd0)) (bv #x00000000 32))
              (shl* (eq* 'phase (bv #x00000004 32)) 'out_prop_bal_sent))
             (list
              (write*
               'd2
               (shr*
                (bv #x00000001 32)
                (bwand*
                 (shl* (bv #x00000001 32) 'out_prop_bal_sent)
                 (bwxor* 'out_prop_bal_vals (bv #xffffffff 32)))))
              (write* 'd0 (lt* (read* 'd1) (bv #x00000001 32)))
              (:=*
               'out_prop_bal_sent
               (add* (bv #x00000001 32) 'out_prop_bal_sent)))
             (list
              (if*
               (bwand*
                (and*
                 (bwand* 'out_prop_bal_sent (bv #xffffffe0 32))
                 (and*
                  (shr*
                   (bv #x00400008 32)
                   (bwand* 'out_prop_val_sent (bv #xffffffe0 32)))
                  (eq* 'phase (bv #x00000004 32))))
                (eq* (bwxor* (read* 'd1) (read* 'd0)) (bv #x00000000 32)))
               (list
                (write*
                 'd2
                 (eq*
                  (bv #x00000000 32)
                  (bwand*
                   (bwxor* (bv #xffffffff 32) 'out_prop_val_vals)
                   (shl* (bv #x00000001 32) 'out_prop_val_sent))))
                (write* 'd0 (lt* (read* 'd1) (bv #x00000001 32)))
                (:=*
                 'out_prop_val_sent
                 (add* (bv #x00000001 32) 'out_prop_val_sent)))
               (list
                (if*
                 (and*
                  (bwand* (bv #xffffffe0 32) 'out_prop_val_sent)
                  (eq* 'phase (bv #x00000004 32)))
                 (list
                  (:=* 'in_prop_bal_rcvd (bv #x00000000 32))
                  (:=* 'in_prop_bal_vals (bv #x00000000 32))
                  (:=* 'in_prop_val_rcvd (bv #x00000000 32))
                  (:=* 'in_prop_val_vals (bv #x00000000 32))
                  (:=* 'phase (bv #x00000005 32)))
                 (list
                  (if*
                   (and*
                    (bwxor* (read* 'd4) (read* 'd3))
                    (shl* (eq* (bv #x00000005 32) 'phase) 'in_prop_bal_rcvd))
                   (list
                    (:=*
                     'in_prop_bal_vals
                     (bwxor*
                      (bwxor*
                       'in_prop_bal_vals
                       (shl* (read* 'd5) 'in_prop_bal_rcvd))
                      (bwand*
                       (shl* (bv #x00000001 32) 'in_prop_bal_rcvd)
                       'in_prop_bal_vals)))
                    (:=*
                     'in_prop_bal_rcvd
                     (add* (bv #x00000001 32) 'in_prop_bal_rcvd))
                    (write* 'd4 (read* 'd3)))
                   (list
                    (if*
                     (bwand*
                      (and*
                       (bwand* 'in_prop_bal_rcvd (bv #xffffffe0 32))
                       (and*
                        (eq*
                         (shr* 'in_prop_val_rcvd (bv #x00000005 32))
                         (bv #x00000000 32))
                        (eq* (bv #x00000005 32) 'phase)))
                      (add*
                       (bwand*
                        (read* 'd3)
                        (lt* (read* 'd4) (bv #x00000001 32)))
                       (shr* (read* 'd4) (read* 'd3))))
                     (list
                      (:=*
                       'in_prop_val_vals
                       (bwxor*
                        (bwand*
                         'in_prop_val_vals
                         (shl* (bv #x00000001 32) 'in_prop_val_rcvd))
                        (bwxor*
                         'in_prop_val_vals
                         (shl* (read* 'd5) 'in_prop_val_rcvd))))
                      (:=*
                       'in_prop_val_rcvd
                       (add* (bv #x00000001 32) 'in_prop_val_rcvd))
                      (write* 'd4 (read* 'd3)))
                     (list
                      (if*
                       (and*
                        (bwand* 'in_prop_val_rcvd (bv #xffffffe0 32))
                        (eq* 'phase (bv #x00000005 32)))
                       (list
                        (:=* 'prop_mbal 'in_prop_bal_vals)
                        (:=* 'prop_mval 'in_prop_val_vals)
                        (:=* 'phase (bv #x00000006 32)))
                       (list
                        (if*
                         (and*
                          (eq* 'prop_mbal 'prom_bal)
                          (eq* 'phase (bv #x00000006 32)))
                         (list
                          (:=* 'ballot 'prop_mbal)
                          (:=* 'value 'prop_mval)
                          (:=* 'out_prop_bal_sent (bv #x00000000 32))
                          (:=* 'out_prop_bal_vals 'prop_mbal)
                          (:=* 'out_prop_val_sent (bv #x00000000 32))
                          (:=* 'out_prop_val_vals 'prop_mval)
                          (:=* 'phase (bv #x00000007 32)))
                         (list
                          (if*
                           (and*
                            (shl*
                             (eq* 'phase (bv #x00000007 32))
                             'out_prop_bal_sent)
                            (eq*
                             (bwor*
                              (and*
                               (read* 'd0)
                               (lt* (read* 'd1) (bv #x00000001 32)))
                              (bwand*
                               (read* 'd1)
                               (lt* (read* 'd0) (bv #x00000001 32))))
                             (bv #x00000000 32)))
                           (list
                            (write*
                             'd2
                             (eq*
                              (bv #x00000000 32)
                              (bwand*
                               (bwxor* (bv #xffffffff 32) 'out_prop_bal_vals)
                               (shl* (bv #x00000001 32) 'out_prop_bal_sent))))
                            (write* 'd0 (lt* (read* 'd1) (bv #x00000001 32)))
                            (:=*
                             'out_prop_bal_sent
                             (add* 'out_prop_bal_sent (bv #x00000001 32))))
                           (list
                            (if*
                             (bwand*
                              (eq*
                               (bwxor* (read* 'd0) (read* 'd1))
                               (bv #x00000000 32))
                              (and*
                               (shr* 'out_prop_bal_sent (bv #x00000005 32))
                               (and*
                                (shr*
                                 (bv #x00000008 32)
                                 (bwand*
                                  'out_prop_val_sent
                                  (bv #xffffffe0 32)))
                                (eq* 'phase (bv #x00000007 32)))))
                             (list
                              (write*
                               'd2
                               (lt*
                                (bwand*
                                 (shl* (bv #x00000001 32) 'out_prop_val_sent)
                                 (bwxor*
                                  (bv #xffffffff 32)
                                  'out_prop_val_vals))
                                (bv #x00000001 32)))
                              (write* 'd0 (lt* (read* 'd1) (bv #x00000001 32)))
                              (:=*
                               'out_prop_val_sent
                               (add* 'out_prop_val_sent (bv #x00000001 32))))
                             (list
                              (if*
                               (and*
                                (bwand* (bv #xffffffe0 32) 'out_prop_val_sent)
                                (eq* (bv #x00000007 32) 'phase))
                               (list (:=* 'phase (bv #x00000000 32)))
                               ;; '()
                               (list
                                (if*
                                 (bv #xffffffff 32)
                                 '()
                                 '()))
                               )))))))))))))))))))))))))))))))

(define proposer-impl
  (arduino*
  (setup*
   (list
    (unsigned-int* 'ballot)
    (unsigned-int* 'value)
    (unsigned-int* 'phase)
    (unsigned-int* 'a_mbal)
    (unsigned-int* 'b_mbal)
    (unsigned-int* 'c_mbal)
    (unsigned-int* 'a_mval)
    (unsigned-int* 'b_mval)
    (unsigned-int* 'c_mval)
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
    (unsigned-int* 'out_a_bal_vals)
    (unsigned-int* 'out_a_bal_sent)
    (unsigned-int* 'out_b_bal_vals)
    (unsigned-int* 'out_b_bal_sent)
    (unsigned-int* 'out_c_bal_vals)
    (unsigned-int* 'out_c_bal_sent)
    (unsigned-int* 'out_a_val_vals)
    (unsigned-int* 'out_a_val_sent)
    (unsigned-int* 'out_b_val_vals)
    (unsigned-int* 'out_b_val_sent)
    (unsigned-int* 'out_c_val_vals)
    (unsigned-int* 'out_c_val_sent)
    (unsigned-int* 'in_a_bal_vals)
    (unsigned-int* 'in_a_bal_rcvd)
    (unsigned-int* 'in_b_bal_vals)
    (unsigned-int* 'in_b_bal_rcvd)
    (unsigned-int* 'in_c_bal_vals)
    (unsigned-int* 'in_c_bal_rcvd)
    (unsigned-int* 'in_a_val_vals)
    (unsigned-int* 'in_a_val_rcvd)
    (unsigned-int* 'in_b_val_vals)
    (unsigned-int* 'in_b_val_rcvd)
    (unsigned-int* 'in_c_val_vals)
    (unsigned-int* 'in_c_val_rcvd)
    (:=* 'ballot (bv #x00000001 32))
    (:=* 'value (bv #x00000020 32))
    (:=* 'phase (bv #x00000001 32))))
  (loop*
   (list
    (if*
     (eq* (bv #x000000ff 32) 'ballot)
     (list (:=* 'phase (bv #x000000ff 32)))
     (list
      (if*
       (eq* 'phase (bv #x00000001 32))
       (list
        (:=* 'out_a_bal_sent (bv #x00000000 32))
        (:=* 'out_a_bal_vals 'ballot)
        (:=* 'out_b_bal_sent (bv #x00000000 32))
        (:=* 'out_b_bal_vals 'ballot)
        (:=* 'out_c_bal_sent (bv #x00000000 32))
        (:=* 'out_c_bal_vals 'ballot)
        (:=* 'phase (bv #x00000002 32)))
       (list
        (if*
         (and*
          (eq* (read* 'd1) (read* 'd0))
          (shl* (eq* (bv #x00000002 32) 'phase) 'out_a_bal_sent))
         (list
          (write*
           'd2
           (bwand* (bv #x00000001 32) (shr* 'out_a_bal_vals 'out_a_bal_sent)))
          (write* 'd0 (lt* (read* 'd1) (bv #x00000001 32)))
          (:=* 'out_a_bal_sent (add* (bv #x00000001 32) 'out_a_bal_sent)))
         (list
          (if*
           (bwand*
            (bwand*
             (lt* (shr* 'out_b_bal_sent (bv #x00000005 32)) (bv #x00000001 32))
             (eq* 'phase (bv #x00000002 32)))
            (eq* (read* 'd4) (read* 'd3)))
           (list
            (write*
             'd5
             (bwand*
              (bv #x00000001 32)
              (shr* 'out_b_bal_vals 'out_b_bal_sent)))
            (write* 'd3 (lt* (read* 'd3) (bv #x00000001 32)))
            (:=* 'out_b_bal_sent (add* (bv #x00000001 32) 'out_b_bal_sent)))
           (list
            (if*
             (bwand*
              (lt*
               (or*
                (bwand* (read* 'd7) (lt* (read* 'd6) (bv #x00000001 32)))
                (and* (read* 'd6) (lt* (read* 'd7) (bv #x00000001 32))))
               (bv #x00000001 32))
              (bwand*
               (shr*
                (bv #x80004803 32)
                (bwand* 'out_c_bal_sent (bv #xffffffe0 32)))
               (eq* (bv #x00000002 32) 'phase)))
             (list
              (write*
               'd8
               (bwand*
                (shr* 'out_c_bal_vals 'out_c_bal_sent)
                (bv #x00000001 32)))
              (write* 'd6 (lt* (read* 'd6) (bv #x00000001 32)))
              (:=* 'out_c_bal_sent (add* (bv #x00000001 32) 'out_c_bal_sent)))
             (list
              (if*
               (and*
                (and*
                 (shr* 'out_b_bal_sent (bv #x00000005 32))
                 (and*
                  (eq* 'phase (bv #x00000002 32))
                  (bwand* 'out_c_bal_sent (bv #xffffffe0 32))))
                (bwand* (bv #xffffffe0 32) 'out_a_bal_sent))
               (list
                (:=* 'in_a_bal_rcvd (bv #x00000000 32))
                (:=* 'in_a_bal_vals (bv #x00000000 32))
                (:=* 'in_b_bal_rcvd (bv #x00000000 32))
                (:=* 'in_b_bal_vals (bv #x00000000 32))
                (:=* 'in_c_bal_rcvd (bv #x00000000 32))
                (:=* 'in_c_bal_vals (bv #x00000000 32))
                (:=* 'in_a_val_rcvd (bv #x00000000 32))
                (:=* 'in_a_val_vals (bv #x00000000 32))
                (:=* 'in_b_val_rcvd (bv #x00000000 32))
                (:=* 'in_b_val_vals (bv #x00000000 32))
                (:=* 'in_c_val_rcvd (bv #x00000000 32))
                (:=* 'in_c_val_vals (bv #x00000000 32))
                (:=* 'phase (bv #x00000003 32)))
               (list
                (if*
                 (bwand*
                  (or*
                   (bwand* (read* 'd9) (lt* (read* 'd10) (bv #x00000001 32)))
                   (lt* (read* 'd9) (read* 'd10)))
                  (and*
                   (eq* (bv #x00000003 32) 'phase)
                   (shl* (bv #x00110151 32) 'in_a_bal_rcvd)))
                 (list
                  (:=*
                   'in_a_bal_vals
                   (bwxor*
                    (bwor*
                     (bwxor* (bv #xffffffff 32) 'in_a_bal_vals)
                     (shl* (bv #x00000001 32) 'in_a_bal_rcvd))
                    (bwxor*
                     (bv #xffffffff 32)
                     (shl* (read* 'd11) 'in_a_bal_rcvd))))
                  (:=* 'in_a_bal_rcvd (add* (bv #x00000001 32) 'in_a_bal_rcvd))
                  (write* 'd10 (read* 'd9)))
                 (list
                  (if*
                   (and*
                    (and*
                     (shl* (eq* 'phase (bv #x00000003 32)) 'in_a_val_rcvd)
                     (bwand* 'in_a_bal_rcvd (bv #xffffffe0 32)))
                    (bwxor* (read* 'd10) (read* 'd9)))
                   (list
                    (:=*
                     'in_a_val_vals
                     (bwxor*
                      (bwor*
                       (bwxor* (bv #xffffffff 32) 'in_a_val_vals)
                       (shl* (bv #x00000001 32) 'in_a_val_rcvd))
                      (bwxor*
                       (shl* (read* 'd11) 'in_a_val_rcvd)
                       (bv #xffffffff 32))))
                    (:=*
                     'in_a_val_rcvd
                     (add* (bv #x00000001 32) 'in_a_val_rcvd))
                    (write* 'd10 (read* 'd9)))
                   (list
                    (if*
                     (bwand*
                      (and*
                       (shr* (bv #xd6c28202 32) 'in_b_bal_rcvd)
                       (eq* (bv #x00000003 32) 'phase))
                      (bwxor* (read* 'd13) (read* 'd12)))
                     (list
                      (:=*
                       'in_b_bal_vals
                       (bwxor*
                        (bwxor*
                         (shl* (read* 'd14) 'in_b_bal_rcvd)
                         (bv #xffffffff 32))
                        (bwor*
                         (bwxor* 'in_b_bal_vals (bv #xffffffff 32))
                         (shl* (bv #x00000001 32) 'in_b_bal_rcvd))))
                      (:=*
                       'in_b_bal_rcvd
                       (add* (bv #x00000001 32) 'in_b_bal_rcvd))
                      (write* 'd13 (read* 'd12)))
                     (list
                      (if*
                       (bwand*
                        (bwxor* (read* 'd13) (read* 'd12))
                        (and*
                         (lt* (bv #x0000001f 32) 'in_b_bal_rcvd)
                         (shl*
                          (eq* (bv #x00000003 32) 'phase)
                          'in_b_val_rcvd)))
                       (list
                        (:=*
                         'in_b_val_vals
                         (bwxor*
                          (bwor*
                           (bwxor* (bv #xffffffff 32) 'in_b_val_vals)
                           (shl* (bv #x00000001 32) 'in_b_val_rcvd))
                          (bwxor*
                           (shl* (read* 'd14) 'in_b_val_rcvd)
                           (bv #xffffffff 32))))
                        (:=*
                         'in_b_val_rcvd
                         (add* (bv #x00000001 32) 'in_b_val_rcvd))
                        (write* 'd13 (read* 'd12)))
                       (list
                        (if*
                         (bwand*
                          (bwxor* (read* 'd16) (read* 'd15))
                          (bwand*
                           (eq* (bv #x00000003 32) 'phase)
                           (eq*
                            (lt* (bv #x0000001f 32) 'in_c_bal_rcvd)
                            (bv #x00000000 32))))
                         (list
                          (:=*
                           'in_c_bal_vals
                           (bwxor*
                            (bwor*
                             (shl* (bv #x00000001 32) 'in_c_bal_rcvd)
                             (bwxor* (bv #xffffffff 32) 'in_c_bal_vals))
                            (bwxor*
                             (shl* (read* 'd17) 'in_c_bal_rcvd)
                             (bv #xffffffff 32))))
                          (:=*
                           'in_c_bal_rcvd
                           (add* (bv #x00000001 32) 'in_c_bal_rcvd))
                          (write* 'd16 (read* 'd15)))
                         (list
                          (if*
                           (bwand*
                            (bwand*
                             (bwand*
                              (shr*
                               (bv #x00000001 32)
                               (lt* (bv #x0000001f 32) 'in_c_val_rcvd))
                              (eq* 'phase (bv #x00000003 32)))
                             (lt* (bv #x0000001f 32) 'in_c_bal_rcvd))
                            (bwxor* (read* 'd16) (read* 'd15)))
                           (list
                            (:=*
                             'in_c_val_vals
                             (bwxor*
                              (bwxor*
                               (shl* (read* 'd17) 'in_c_val_rcvd)
                               (bv #xffffffff 32))
                              (bwor*
                               (bwxor* 'in_c_val_vals (bv #xffffffff 32))
                               (shl* (bv #x00000001 32) 'in_c_val_rcvd))))
                            (:=*
                             'in_c_val_rcvd
                             (add* 'in_c_val_rcvd (bv #x00000001 32)))
                            (write* 'd16 (read* 'd15)))
                           (list
                            (if*
                             (and*
                              (bwand* (bv #xffffffe0 32) 'in_a_val_rcvd)
                              (and*
                               (and*
                                (bwand* 'in_c_val_rcvd (bv #xffffffe0 32))
                                (eq* (bv #x00000003 32) 'phase))
                               (bwand* 'in_b_val_rcvd (bv #xffffffe0 32))))
                             (list
                              (:=* 'a_mbal 'in_a_bal_vals)
                              (:=* 'b_mbal 'in_b_bal_vals)
                              (:=* 'c_mbal 'in_c_bal_vals)
                              (:=* 'a_mval 'in_a_val_vals)
                              (:=* 'b_mval 'in_b_val_vals)
                              (:=* 'c_mval 'in_c_val_vals)
                              (:=* 'phase (bv #x00000004 32)))
                             (list
                              (if*
                               (and*
                                (shr*
                                 (and*
                                  (eq* 'phase (bv #x00000004 32))
                                  (lt* 'c_mbal (bv #x00000001 32)))
                                 'b_mbal)
                                (lt* 'a_mbal (bv #x00000001 32)))
                               (list (:=* 'phase (bv #x00000005 32)))
                               (list
                                (if*
                                 (and*
                                  (and*
                                   (bwor*
                                    (lt* 'c_mbal 'a_mbal)
                                    (eq* 'a_mbal 'c_mbal))
                                   (eq* (bv #x00000004 32) 'phase))
                                  (or*
                                   (lt* 'b_mbal 'a_mbal)
                                   (eq* 'a_mbal 'b_mbal)))
                                 (list
                                  (:=* 'value 'a_mval)
                                  (:=* 'phase (bv #x00000005 32)))
                                 (list
                                  (if*
                                   (bwand*
                                    (or*
                                     (lt* 'c_mbal 'b_mbal)
                                     (eq* 'c_mbal 'b_mbal))
                                    (eq* (bv #x00000004 32) 'phase))
                                   (list
                                    (:=* 'value 'b_mval)
                                    (:=* 'phase (bv #x00000005 32)))
                                   (list
                                    (if*
                                     (eq* (bv #x00000004 32) 'phase)
                                     (list
                                      (:=* 'value 'c_mval)
                                      (:=* 'phase (bv #x00000005 32)))
                                     (list
                                      (if*
                                       (eq* (bv #x00000005 32) 'phase)
                                       (list
                                        (:=*
                                         'out_a_bal_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_a_bal_vals 'ballot)
                                        (:=*
                                         'out_b_bal_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_b_bal_vals 'ballot)
                                        (:=*
                                         'out_c_bal_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_c_bal_vals 'ballot)
                                        (:=*
                                         'out_a_val_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_a_val_vals 'value)
                                        (:=*
                                         'out_b_val_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_b_val_vals 'value)
                                        (:=*
                                         'out_c_val_sent
                                         (bv #x00000000 32))
                                        (:=* 'out_c_val_vals 'value)
                                        (:=* 'phase (bv #x00000006 32)))
                                       (list
                                        (if*
                                         (and*
                                          (shl*
                                           (eq* 'phase (bv #x00000006 32))
                                           'out_a_bal_sent)
                                          (eq* (read* 'd1) (read* 'd0)))
                                         (list
                                          (write*
                                           'd2
                                           (bwand*
                                            (bv #x00000001 32)
                                            (shr*
                                             'out_a_bal_vals
                                             'out_a_bal_sent)))
                                          (write*
                                           'd0
                                           (lt*
                                            (read* 'd0)
                                            (bv #x00000001 32)))
                                          (:=*
                                           'out_a_bal_sent
                                           (add*
                                            (bv #x00000001 32)
                                            'out_a_bal_sent)))
                                         (list
                                          (if*
                                           (bwand*
                                            (bwand*
                                             (and*
                                              (eq* (bv #x00000006 32) 'phase)
                                              (shl*
                                               (bv #x00000003 32)
                                               'out_a_val_sent))
                                             (lt*
                                              (bv #x0000001f 32)
                                              'out_a_bal_sent))
                                            (eq*
                                             (bwxor*
                                              (shr* (read* 'd1) (read* 'd0))
                                              (bwand*
                                               (lt*
                                                (read* 'd1)
                                                (bv #x00000001 32))
                                               (read* 'd0)))
                                             (bv #x00000000 32)))
                                           (list
                                            (write*
                                             'd2
                                             (bwand*
                                              (shr*
                                               'out_a_val_vals
                                               'out_a_val_sent)
                                              (bv #x00000001 32)))
                                            (write*
                                             'd0
                                             (lt*
                                              (read* 'd0)
                                              (bv #x00000001 32)))
                                            (:=*
                                             'out_a_val_sent
                                             (add*
                                              (bv #x00000001 32)
                                              'out_a_val_sent)))
                                           (list
                                            (if*
                                             (bwand*
                                              (and*
                                               (shr*
                                                (bv #x00080008 32)
                                                (bwand*
                                                 (bv #xffffffe0 32)
                                                 'out_b_bal_sent))
                                               (eq* 'phase (bv #x00000006 32)))
                                              (shr*
                                               (bv #x00000001 32)
                                               (add*
                                                (and*
                                                 (read* 'd3)
                                                 (lt*
                                                  (read* 'd4)
                                                  (bv #x00000001 32)))
                                                (bwand*
                                                 (read* 'd4)
                                                 (lt*
                                                  (read* 'd3)
                                                  (bv #x00000001 32))))))
                                             (list
                                              (write*
                                               'd5
                                               (bwand*
                                                (bv #x00000001 32)
                                                (shr*
                                                 'out_b_bal_vals
                                                 'out_b_bal_sent)))
                                              (write*
                                               'd3
                                               (lt*
                                                (read* 'd3)
                                                (bv #x00000001 32)))
                                              (:=*
                                               'out_b_bal_sent
                                               (add*
                                                (bv #x00000001 32)
                                                'out_b_bal_sent)))
                                             (list
                                              (if*
                                               (bwand*
                                                (and*
                                                 (shl*
                                                  (eq*
                                                   'phase
                                                   (bv #x00000006 32))
                                                  'out_b_val_sent)
                                                 (shr*
                                                  'out_b_bal_sent
                                                  (bv #x00000005 32)))
                                                (eq*
                                                 (bwor*
                                                  (and*
                                                   (read* 'd3)
                                                   (lt*
                                                    (read* 'd4)
                                                    (bv #x00000001 32)))
                                                  (bwand*
                                                   (read* 'd4)
                                                   (lt*
                                                    (read* 'd3)
                                                    (bv #x00000001 32))))
                                                 (bv #x00000000 32)))
                                               (list
                                                (write*
                                                 'd5
                                                 (bwand*
                                                  (bv #x00000001 32)
                                                  (shr*
                                                   'out_b_val_vals
                                                   'out_b_val_sent)))
                                                (write*
                                                 'd3
                                                 (lt*
                                                  (read* 'd3)
                                                  (bv #x00000001 32)))
                                                (:=*
                                                 'out_b_val_sent
                                                 (add*
                                                  (bv #x00000001 32)
                                                  'out_b_val_sent)))
                                               (list
                                                (if*
                                                 (bwand*
                                                  (and*
                                                   (shl*
                                                    (bv #x08000803 32)
                                                    'out_c_bal_sent)
                                                   (eq*
                                                    (bv #x00000006 32)
                                                    'phase))
                                                  (shr*
                                                   (bv #x00000001 32)
                                                   (bwxor*
                                                    (read* 'd6)
                                                    (read* 'd7))))
                                                 (list
                                                  (write*
                                                   'd8
                                                   (bwand*
                                                    (bv #x00000001 32)
                                                    (shr*
                                                     'out_c_bal_vals
                                                     'out_c_bal_sent)))
                                                  (write*
                                                   'd6
                                                   (lt*
                                                    (read* 'd7)
                                                    (bv #x00000001 32)))
                                                  (:=*
                                                   'out_c_bal_sent
                                                   (add*
                                                    (bv #x00000001 32)
                                                    'out_c_bal_sent)))
                                                 (list
                                                  (if*
                                                   (bwand*
                                                    (eq*
                                                     (read* 'd7)
                                                     (read* 'd6))
                                                    (and*
                                                     (and*
                                                      (eq*
                                                       (bv #x00000006 32)
                                                       'phase)
                                                      (shr*
                                                       (bv #x00000008 32)
                                                       (bwand*
                                                        (bv #xffffffe0 32)
                                                        'out_c_val_sent)))
                                                     (shr*
                                                      'out_c_bal_sent
                                                      (bv #x00000005 32))))
                                                   (list
                                                    (write*
                                                     'd8
                                                     (bwand*
                                                      (shr*
                                                       'out_c_val_vals
                                                       'out_c_val_sent)
                                                      (bv #x00000001 32)))
                                                    (write*
                                                     'd6
                                                     (lt*
                                                      (read* 'd7)
                                                      (bv #x00000001 32)))
                                                    (:=*
                                                     'out_c_val_sent
                                                     (add*
                                                      (bv #x00000001 32)
                                                      'out_c_val_sent)))
                                                   (list
                                                    (if*
                                                     (and*
                                                      (shr*
                                                       'out_a_val_sent
                                                       (bv #x00000005 32))
                                                      (and*
                                                       (bwand*
                                                        'out_b_val_sent
                                                        (bv #xffffffe0 32))
                                                       (and*
                                                        (shr*
                                                         'out_c_val_sent
                                                         (bv #x00000005 32))
                                                        (eq*
                                                         (bv #x00000006 32)
                                                         'phase))))
                                                     (list
                                                      (:=*
                                                       'in_a_bal_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_a_bal_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_b_bal_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_b_bal_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_c_bal_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_c_bal_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_a_val_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_a_val_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_b_val_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_b_val_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_c_val_rcvd
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'in_c_val_vals
                                                       (bv #x00000000 32))
                                                      (:=*
                                                       'phase
                                                       (bv #x00000007 32)))
                                                     (list
                                                      (if*
                                                       (bwand*
                                                        (or*
                                                         (shr*
                                                          (read* 'd9)
                                                          (read* 'd10))
                                                         (shr*
                                                          (read* 'd10)
                                                          (read* 'd9)))
                                                        (and*
                                                         (eq*
                                                          'phase
                                                          (bv #x00000007 32))
                                                         (shr*
                                                          (bv #x00000008 32)
                                                          (bwand*
                                                           'in_a_bal_rcvd
                                                           (bv #xffffffe0 32)))))
                                                       (list
                                                        (:=*
                                                         'in_a_bal_vals
                                                         (bwxor*
                                                          (bwxor*
                                                           (bv #xffffffff 32)
                                                           (shl*
                                                            (read* 'd11)
                                                            'in_a_bal_rcvd))
                                                          (bwor*
                                                           (bwxor*
                                                            (bv #xffffffff 32)
                                                            'in_a_bal_vals)
                                                           (shl*
                                                            (bv #x00000001 32)
                                                            'in_a_bal_rcvd))))
                                                        (:=*
                                                         'in_a_bal_rcvd
                                                         (add*
                                                          (bv #x00000001 32)
                                                          'in_a_bal_rcvd))
                                                        (write*
                                                         'd10
                                                         (read* 'd9)))
                                                       (list
                                                        (if*
                                                         (and*
                                                          (or*
                                                           (shr*
                                                            (read* 'd9)
                                                            (read* 'd10))
                                                           (shr*
                                                            (read* 'd10)
                                                            (read* 'd9)))
                                                          (and*
                                                           (lt*
                                                            (bv #x0000001f 32)
                                                            'in_a_bal_rcvd)
                                                           (shl*
                                                            (eq*
                                                             'phase
                                                             (bv #x00000007 32))
                                                            'in_a_val_rcvd)))
                                                         (list
                                                          (:=*
                                                           'in_a_val_vals
                                                           (bwxor*
                                                            (bwor*
                                                             (bwxor*
                                                              (bv #xffffffff 32)
                                                              'in_a_val_vals)
                                                             (shl*
                                                              (bv #x00000001 32)
                                                              'in_a_val_rcvd))
                                                            (bwxor*
                                                             (bv #xffffffff 32)
                                                             (shl*
                                                              (read* 'd11)
                                                              'in_a_val_rcvd))))
                                                          (:=*
                                                           'in_a_val_rcvd
                                                           (add*
                                                            (bv #x00000001 32)
                                                            'in_a_val_rcvd))
                                                          (write*
                                                           'd10
                                                           (read* 'd9)))
                                                         (list
                                                          (if*
                                                           (and*
                                                            (or*
                                                             (shr*
                                                              (read* 'd12)
                                                              (read* 'd13))
                                                             (shr*
                                                              (read* 'd13)
                                                              (read* 'd12)))
                                                            (and*
                                                             (shr*
                                                              (bv #x00000008 32)
                                                              (bwand*
                                                               (bv #xffffffe0 32)
                                                               'in_b_bal_rcvd))
                                                             (eq*
                                                              (bv #x00000007 32)
                                                              'phase)))
                                                           (list
                                                            (:=*
                                                             'in_b_bal_vals
                                                             (bwxor*
                                                              (bwor*
                                                               (shl*
                                                                (bv #x00000001 32)
                                                                'in_b_bal_rcvd)
                                                               (bwxor*
                                                                'in_b_bal_vals
                                                                (bv #xffffffff 32)))
                                                              (bwxor*
                                                               (bv #xffffffff 32)
                                                               (shl*
                                                                (read* 'd14)
                                                                'in_b_bal_rcvd))))
                                                            (:=*
                                                             'in_b_bal_rcvd
                                                             (add*
                                                              (bv #x00000001 32)
                                                              'in_b_bal_rcvd))
                                                            (write*
                                                             'd13
                                                             (read* 'd12)))
                                                           (list
                                                            (if*
                                                             (bwand*
                                                              (and*
                                                               (and*
                                                                (eq*
                                                                 (bv #x00000007 32)
                                                                 'phase)
                                                                (shl*
                                                                 (bv #x00000008 32)
                                                                 (bwand*
                                                                  'in_b_val_rcvd
                                                                  (bv #xffffffe0 32))))
                                                               (shr*
                                                                'in_b_bal_rcvd
                                                                (bv #x00000005 32)))
                                                              (or*
                                                               (shr*
                                                                (read* 'd12)
                                                                (read* 'd13))
                                                               (shr*
                                                                (read* 'd13)
                                                                (read* 'd12))))
                                                             (list
                                                              (:=*
                                                               'in_b_val_vals
                                                               (bwxor*
                                                                (bwor*
                                                                 (shl*
                                                                  (bv #x00000001 32)
                                                                  'in_b_val_rcvd)
                                                                 (bwxor*
                                                                  'in_b_val_vals
                                                                  (bv #xffffffff 32)))
                                                                (bwxor*
                                                                 (shl*
                                                                  (read* 'd14)
                                                                  'in_b_val_rcvd)
                                                                 (bv #xffffffff 32))))
                                                              (:=*
                                                               'in_b_val_rcvd
                                                               (add*
                                                                'in_b_val_rcvd
                                                                (bv #x00000001 32)))
                                                              (write*
                                                               'd13
                                                               (read* 'd12)))
                                                             (list
                                                              (if*
                                                               (and*
                                                                (shl*
                                                                 (eq*
                                                                  (bv #x00000007 32)
                                                                  'phase)
                                                                 'in_c_bal_rcvd)
                                                                (or*
                                                                 (shr*
                                                                  (read* 'd15)
                                                                  (read* 'd16))
                                                                 (shr*
                                                                  (read* 'd16)
                                                                  (read*
                                                                   'd15))))
                                                               (list
                                                                (:=*
                                                                 'in_c_bal_vals
                                                                 (bwxor*
                                                                  (bwxor*
                                                                   (bv #xffffffff 32)
                                                                   (shl*
                                                                    (read*
                                                                     'd17)
                                                                    'in_c_bal_rcvd))
                                                                  (bwor*
                                                                   (shl*
                                                                    (bv #x00000001 32)
                                                                    'in_c_bal_rcvd)
                                                                   (bwxor*
                                                                    (bv #xffffffff 32)
                                                                    'in_c_bal_vals))))
                                                                (:=*
                                                                 'in_c_bal_rcvd
                                                                 (add*
                                                                  (bv #x00000001 32)
                                                                  'in_c_bal_rcvd))
                                                                (write*
                                                                 'd16
                                                                 (read* 'd15)))
                                                               (list
                                                                (if*
                                                                 (and*
                                                                  (bwxor*
                                                                   (read* 'd15)
                                                                   (read*
                                                                    'd16))
                                                                  (and*
                                                                   (bwand*
                                                                    'in_c_bal_rcvd
                                                                    (bv #xffffffe0 32))
                                                                   (and*
                                                                    (shr*
                                                                     (bv #x00000008 32)
                                                                     (bwand*
                                                                      (bv #xffffffe0 32)
                                                                      'in_c_val_rcvd))
                                                                    (eq*
                                                                     (bv #x00000007 32)
                                                                     'phase))))
                                                                 (list
                                                                  (:=*
                                                                   'in_c_val_vals
                                                                   (bwxor*
                                                                    (bwor*
                                                                     (bwxor*
                                                                      'in_c_val_vals
                                                                      (bv #xffffffff 32))
                                                                     (shl*
                                                                      (bv #x00000001 32)
                                                                      'in_c_val_rcvd))
                                                                    (bwxor*
                                                                     (bv #xffffffff 32)
                                                                     (shl*
                                                                      (read*
                                                                       'd17)
                                                                      'in_c_val_rcvd))))
                                                                  (:=*
                                                                   'in_c_val_rcvd
                                                                   (add*
                                                                    (bv #x00000001 32)
                                                                    'in_c_val_rcvd))
                                                                  (write*
                                                                   'd16
                                                                   (read*
                                                                    'd15)))
                                                                 (list
                                                                  (if*
                                                                   (and*
                                                                    (bwand*
                                                                     'in_a_val_rcvd
                                                                     (bv #xffffffe0 32))
                                                                    (and*
                                                                     (and*
                                                                      (eq*
                                                                       'phase
                                                                       (bv #x00000007 32))
                                                                      (lt*
                                                                       (bv #x0000001f 32)
                                                                       'in_c_val_rcvd))
                                                                     (bwand*
                                                                      'in_b_val_rcvd
                                                                      (bv #xffffffe0 32))))
                                                                   (list
                                                                    (:=*
                                                                     'a_mbal
                                                                     'in_a_bal_vals)
                                                                    (:=*
                                                                     'b_mbal
                                                                     'in_b_bal_vals)
                                                                    (:=*
                                                                     'c_mbal
                                                                     'in_c_bal_vals)
                                                                    (:=*
                                                                     'a_mval
                                                                     'in_a_val_vals)
                                                                    (:=*
                                                                     'b_mval
                                                                     'in_b_val_vals)
                                                                    (:=*
                                                                     'c_mval
                                                                     'in_c_val_vals)
                                                                    (:=*
                                                                     'phase
                                                                     (bv #x00000008 32)))
                                                                   (list
                                                                    (if*
                                                                     (and*
                                                                      (bwand*
                                                                       (eq*
                                                                        'b_mval
                                                                        'value)
                                                                       (bwand*
                                                                        (eq*
                                                                         'c_mval
                                                                         'value)
                                                                        (eq*
                                                                         (bv #x00000008 32)
                                                                         'phase)))
                                                                      (eq*
                                                                       'a_mval
                                                                       'value))
                                                                     (list
                                                                      (:=*
                                                                       'phase
                                                                       (bv #x00000000 32)))
                                                                     (list
                                                                      (if*
                                                                       (eq*
                                                                        (bv #x00000008 32)
                                                                        'phase)
                                                                       (list
                                                                        (:=*
                                                                         'phase
                                                                         (bv #x000000ff 32)))
                                                                       ;; '()
                                                                       (list
                                                                        (if*
                                                                         (bv #xffffffff 32)
                                                                         '()
                                                                         '()))
                                                                       )))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))

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

;; (let* ([prog mini-test]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (time (list impl
;;               (verify-arduino-prog prog impl))))

;; synth cpu time: 290554 real time: 4019873 gc time: 79792
;; verify cpu time: 1496362 real time: 1928454 gc time: 1271628
;; (let* ([prog proposer]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (time (list impl
;;               (verify-arduino-prog prog impl))))

;; synth cpu time: 1549185 real time: 7399315 gc time: 270622
;; verify cpu time: 100967 real time: 759723 gc time: 6565
;; (let* ([prog proposer]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (list (time (verify-arduino-prog prog impl))
;;         impl))

;; synth cpu time: 60854 real time: 2012298 gc time: 4067
;; verify cpu time: 3772 real time: 8831 gc time: 249
;; (let* ([prog acceptor]
;;        [impl (time (unity-prog->arduino-prog prog))])
;;   (list (time (verify-arduino-prog prog impl))
;;         impl))

(let* ([prog proposer]
       [impl proposer-impl])
  (time (verify-arduino-prog prog impl)))

;; (let* ([prog acceptor]
;;        [impl acceptor-impl])
;;   (time (verify-arduino-prog prog impl)))

;; (output-smt "/Users/cchen/Desktop/smt")
