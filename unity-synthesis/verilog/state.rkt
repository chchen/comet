#lang rosette

(require "context.rkt")

;; Definitions regarding state handling

;; We model the state as an associative list from symbols to
;; values. Values are updated by adding a new value to the list. Entries
;; are never removed.

;; The latest value of the variable v in the state store.
;; 'referr is returned if v does not exist as a mapping in state
(define (state-get v cxt state)
  (if (can-read? v cxt)
      (let ([rv (assoc v state)])
        (if rv
            (cdr rv)
            'referr))
      'typerr))

;; Adds a new value mapping for variable v in the state store
(define (state-put v e cxt state)
  (if (can-write? v cxt)
      (cons (cons v e) state)
      'typerr))

(provide state-get
         state-put)
