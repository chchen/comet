#lang rosette

(require "../util.rkt")

;; Channel types.
;; Channels are declared as 'channel-read or 'channel-write but the state
;; representation is the channel* struct, which contains two fields:
;; 1) validity
;; 2) value
(struct channel*
  (valid
   value)
  #:transparent)

;; Channel syntactic forms
;; Construct a message Bool -> Channel
(struct message*
  (value)
  #:transparent)

;; Destruct a message Channel -> Bool
;; Partial Function! Only defined for valid channels
(struct value*
  (channel)
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
;; These terms combine into arbitrary boolean expressions.
;; Terminals are: #t, #f, 'empty
;; Variable reference
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
(struct eq?*
  (left
   right)
  #:transparent)
;; Channel emptiness (Channel -> Bool)
(struct empty?*
  (chan)
  #:transparent)
;; Channel fullness (Channel -> Bool)
(struct full?*
  (chan)
  #:transparent)

;; Export the following from the module:
(provide channel*
         channel*-valid
         channel*-value
         message*
         value*
         unity*
         declare*
         initially*
         assign*
         :=*
         case*
         not*
         and*
         or*
         eq?*
         empty?*
         full?*)

;; Example syntax

;; (unity*
;;  (declare* (list (cons 'reg 'boolean)
;;                  (cons 'out 'channel-write)))
;;  (initially* (:=* (list 'reg
;;                         'out)
;;                   (list #f
;;                         'empty)))
;;  (assign* (list (:=* (list 'reg
;;                            'out)
;;                      (case* (list (cons (list (not* 'reg)
;;                                               (message* 'reg))
;;                                         (empty?* 'out))))))))
