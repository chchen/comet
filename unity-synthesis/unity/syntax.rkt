#lang rosette/safe

(require "../config.rkt"
         "../util.rkt"
         rosette/lib/match)

;; Types
;; Boolean (true/false)
;; Channel (full/empty containers for booleans)
;; Nat (0, 1, 2...)
;; Send-buf (N-ary lists of booleans in "big-endian")
;; Recv-buf (N-ary lists of booleans in "little-endian")
;;
;; Terminals: #t, #f, 'empty, natural numbers

;; Channel types. Two fields:
;; 1) validity
;; 2) value
(struct channel*
  (valid
   value)
  #:transparent)

;; Boolean buffer with a cursor
(struct buffer*
  (cursor
   vals)
  #:transparent)

;; Top-level syntax.
;; A UNITY program consists of a triple:
;; 1) a declaration of variable types
;; 2) an initial (multi-)assignment
;; 3) a list of (multi-)assignments
(struct unity*
  (declare
   initially
   assign)
  #:transparent)

;; Declaration clause.
;; A list of pairs:
;; 1) a identifier (a symbol)
;; 2) a type
(struct declare*
  (variable-declarations)
  #:transparent)

;; Initially section
;; Contains an assignment statement.
(struct initially*
  (assignment-statement)
  #:transparent)

;; Assign section
;; Contains a list of assignment statements.
(struct assign*
  (assignment-statements)
  #:transparent)

;; Assignment statement
;; 1) List of variables to set
;; 2) A list of expressions that yield values OR
;;    A case statement
(struct :=*
  (variables
   expressions)
  #:transparent)

;; Assignment-by-cases
;; Contains a list of pairs
;; 1) A list of expressions
;; 2) A boolean expression
(struct case*
  (case-list)
  #:transparent)

;; Expressions

;; Negation (Bool -> Bool)
(struct not* (exp) #:transparent)

;; Logical AND (Bool x Bool -> Bool)
(struct and*
  (left
   right)
  #:transparent)

;; Logical OR (Bool x Bool -> Bool)
(struct or*
  (left
   right)
  #:transparent)

;; Equality (Bool x Bool -> Bool)
(struct eq*
  (left
   right)
  #:transparent)

;; Nat Addition
(struct +*
  (left
   right)
  #:transparent)

;; Nat Less-Than
(struct <*
  (left
   right))

;; Nat Equality
(struct =*
  (left
   right))

;; Channel not valid (Channel -> Bool)
(struct empty?*
  (chan)
  #:transparent)

;; Channel valid (Channel -> Bool)
(struct full?*
  (chan)
  #:transparent)

;; Send-buf* exhausted
(struct send-buf-empty?*
  (buf)
  #:transparent)

;; Recv-buf* ready
(struct recv-buf-full?*
  (buf)
  #:transparent)

;; Construct a message Bool -> Channel
(struct message*
  (value)
  #:transparent)

;; Destruct a message Channel -> Bool
;; Partial Function! Only defined for valid channels
(struct value*
  (channel)
  #:transparent)

;; Nat -> empty Recv-buf*
(struct empty-recv-buf*
  (len)
  #:transparent)

;; Nat -> empty Send-buf*
(struct empty-send-buf*
  (len)
  #:transparent)

;; New recv-buf* with an item added to an existing recv-buf*
;; Partial function! Only defined for non-full recv-buf*
;; Recv-buf* -> Bool -> Recv-buf*
(struct recv-buf-put*
  (buf
   item)
  #:transparent)

;; The natural number equivalent of a recv-buf*
;; Partial function! Only defined for full recv-buf*
;; Recv-buf* -> Nat
(struct recv-buf->nat*
  (buf)
  #:transparent)

;; Nat_1 -> Nat_2 -> Send-buf*
;; Buffer represents Nat_2 in length Nat_1
(struct nat->send-buf*
  (len
   value)
  #:transparent)

;; The next item in the send-buf*
;; Partial function! Only defined for non-empty send-buf*
;; Send-buf* -> Bool
(struct send-buf-get*
  (buf)
  #:transparent)

;; New send-buf* where send-buf-get* yields the next item
;; Partial function! Only defined for non-empty send-buf*
;; Send-buf* -> Send-buf*
(struct send-buf-next*
  (buf)
  #:transparent)

;; Export the following from the module:
(provide channel*
         channel*?
         channel*-valid
         channel*-value
         buffer*
         buffer*?
         buffer*-cursor
         buffer*-vals
         unity*
         declare*
         initially*
         assign*
         :=*
         case*
         not*
         and*
         or*
         eq*
         +*
         <*
         =*
         empty?*
         full?*
         recv-buf-full?*
         send-buf-empty?*
         message*
         value*
         empty-recv-buf*
         empty-send-buf*
         recv-buf-put*
         recv-buf->nat*
         nat->send-buf*
         send-buf-get*
         send-buf-next*
         unity-example-program
         )

;; Example syntax

(define unity-example-program
  (unity*
   (declare*
    (list (cons 'in-read 'boolean)
          (cons 'in 'recv-channel)
          (cons 'out 'send-channel)
          (cons 'inbox 'recv-buf)
          (cons 'outbox 'send-buf)))
   (initially*
    (list
     (:=* (list 'in-read
                'inbox
                'outbox)
          (list 42
                #f
                (nat->send-buf* vect-len 42)
                (empty-recv-buf* vect-len)))))
   (assign*
    (list
     ;; non-deterministic choice #1
     ;; at the moment, COMET synthesizes deterministic specifications only
     (list
      ;; parallel assignment #1a
      (:=* (list 'in-read
                 'out)
           (case* (list (cons (list #t
                                    (message* (value* 'in)))
                              (and* (not* 'in-read)
                                    (and* (empty?* 'out)
                                          (full?* 'in)))))))
      ;; parallel assignment #1b
      (:=* (list 'in-read
                 'in)
           (case* (list (cons (list #f
                                    'empty)
                              (and* 'in-read
                                    (full?* 'in)))))))))))

(assert
 (unity*? unity-example-program))
