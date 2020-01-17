#lang rosette

(struct environment* (context state) #:transparent)
(struct context* (vars read-pins write-pins) #:transparent)
(struct state* (vars pins) #:transparent)

(define empty-context
  (context* '() '() '()))

(define (env-context env)
  (match env
    [(environment* c _) c]))

(define (env-state env)
  (match env
    [(environment* _ s) s]))

(define (context-vars cxt)
  (match cxt
    [(context* v _ _) v]))

(define (context-readable-pins cxt)
  (match cxt
    [(context* _ r _) r]))

(define (context-writable-pins cxt)
  (match cxt
    [(context* _ _ w) w]))

(define (state-vars state)
  (match state
    [(state* v _) v]))

(define (state-pins state)
  (match state
    [(state* _ p) p]))

(provide environment*
         context*
         state*
         empty-context
         env-context
         env-state
         context-vars
         context-readable-pins
         context-writable-pins
         state-vars
         state-pins)
