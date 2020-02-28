#lang rosette

(require "../util.rkt")

;; ;; Types
;; ;; We currently support boolean variables
;; ;; and unidirectional channels that (can) contain booleans
;; (define (valid-type? t)
;;   (in-list? t
;;             (list 'boolean 'channel-read 'channel-write)))

;; (define (valid-read? t)
;;   (valid-type? t))

;; (define (valid-write? t)
;;   (in-list? t
;;             (list 'boolean 'channel-write)))

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
(provide unity*
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
;;  (initially* (:=* (list 'reg 'out)
;;                   (list #f 'empty)))
;;  (assign* (list (:=* (list 'reg 'out)
;;                      (case* (list (cons (list (not* 'reg) 'reg)
;;                                         (eq?* 'out 'empty))))))))
