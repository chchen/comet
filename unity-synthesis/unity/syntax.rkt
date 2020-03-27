#lang rosette

(require "../util.rkt")

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

;; Send buffer type. Booleans in "big endian" order
;; len is the original length
(struct send-buf*
  (len
   val)
  #:transparent)

;; Receive buffer type. Booleans in "little endian" order
;; len is the length when full
(struct recv-buf*
  (len
   val)
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
(struct send-empty?*
  (buf)
  #:transparent)

;; Recv-buf* ready
(struct recv-full?*
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

;; Construct a send buffer Nat x Nat -> Send-buf*
(struct nat->send-buf*
  (len
   value)
  #:transparent)

;; The next (head) item in the send-buffer
;; Partial function! Only defined for non-empty send-buf*
;; Send-buf* -> Bool
(struct send-buf-head*
  (buf)
  #:transparent)

;; The remainder of the send-buffer
;; Partial function! Only defined for non-empty send-buf*
;; Send-buf* -> Send-buf*
(struct send-buf-tail*
  (buf)
  #:transparent)

;; Construct an empty recv buffer Nat -> Recv-buf*
(struct empty-recv-buf*
  (len)
  #:transparent)

;; Construct a new receive buffer with an item and an existing receive buffer
;; Partial function! Only defined for non-full recv-buf*
;; Recv-buf* x Bool -> Recv-buf*
(struct recv-buf-insert*
  (buf
   item)
  #:transparent)

;; The natural number equivalent of a recv-buf*
;; Partial function! Only defined for full recv-buf*
;; Recv-buf* -> Nat
(struct recv-buf->nat*
  (buf)
  #:transparent)

;; Export the following from the module:
(provide channel*
         channel*?
         channel*-valid
         channel*-value
         send-buf*
         send-buf*?
         send-buf*-len
         send-buf*-val
         recv-buf*
         recv-buf*?
         recv-buf*-len
         recv-buf*-val
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
         send-empty?*
         recv-full?*
         message*
         value*
         nat->send-buf*
         send-buf-head*
         send-buf-tail*
         empty-recv-buf*
         recv-buf-insert*
         recv-buf->nat*
         )

;; Example syntax

;; (unity*
;;  (declare* (list (cons 'reg 'boolean)
;;                  (cons 'out 'channel)))
;;  (initially* (:=* (list 'reg
;;                         'out)
;;                   (list #f
;;                         'empty)))
;;  (assign* (list (:=* (list 'reg
;;                            'out)
;;                      (case* (list (cons (list (not* 'reg)
;;                                               (message* 'reg))
;;                                         (empty?* 'out))))))))
