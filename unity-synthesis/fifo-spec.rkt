#lang rosette

;; Functional spec for the FIFO stage
(define (fifospec pins)
  (let ([lReq (vector-ref pins 0)]
        [lAck (vector-ref pins 1)]
        [rReq (vector-ref pins 2)]
        [rAck (vector-ref pins 3)])
    (if (and (not (eq? lReq lAck))
             (eq? rReq rAck))
        (begin
          (vector-set! pins 1 lReq)
          (vector-set! pins 2 (not rAck))
          pins)
        pins)))

;; Functional spec for the FIFO guard
(define (guardspec pins)
  (let ([lReq (vector-ref pins 0)]
        [lAck (vector-ref pins 1)]
        [rReq (vector-ref pins 2)]
        [rAck (vector-ref pins 3)])
    (and (not (eq? lReq lAck))
         (eq? rReq rAck))))

;; Functional spec for the FIFO action
(define (actionspec pins)
  (let ([lReq (vector-ref pins 0)]
        [lAck (vector-ref pins 1)]
        [rReq (vector-ref pins 2)]
        [rAck (vector-ref pins 3)])
    (begin
      (vector-set! pins 1 lReq)
      (vector-set! pins 2 (not rAck))
      pins)))

;; Functional spec for a single pin assignment
(define (assignspec pins)
  (let ([lReq (vector-ref pins 0)]
        [lAck (vector-ref pins 1)])
    (begin
      (vector-set! pins 0 lAck)
      pins)))

(provide fifospec guardspec assignspec actionspec)