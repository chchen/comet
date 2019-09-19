#lang rosette

;; Top-level syntax.
;; A UNITY program consists of a triple:
;; 1) a list of declaration clauses that define the variables in scope
;;   and if they're readable, writable, or both
;; 2) an initial multi-assignment
;; 3) a list of guarded multi-assignments
(struct unity*
  (declarations
   initial-multi-assignment
   guarded-multi-assignments)
  #:transparent)

;; Declaration clause.
;; A declaration is a pair:
;; 1) a identifier (an atom: a number or symbol)
;; 2) a mode ('read, 'write, 'readwrite)
(struct declare*
  (identifier
   mode)
  #:transparent)

;; Guarded multi-assignment clause.
;; An assignment is a pair:
;; 1) a boolean expression, called the guard
;; 2) a multi-assignment
(struct assign*
  (guard*
   multi-assignment*)
  #:transparent)

;; Guard expressions.
;; These terms combine into arbitrary boolean expressions.
;; Base expressions are one of: #t | #f | (ref* identifier)
;; Variable reference
(struct ref* (var) #:transparent)
;; Negation
(struct not* (exp) #:transparent)
;; Logical AND
(struct and*
  (exp-l*
   exp-r*)
  #:transparent)
;; Logical OR
(struct or*
  (exp-l*
   exp-r)
  #:transparent)
;; Equality
(struct eq*
  (exp-l
   exp-r)
  #:transparent)

;; Multi-assignment.
;; A multi-assignment is a pair:
;; 1) A list of variable identifiers
;; 2) A list of boolean expressions
(struct multi-assignment*
  (variables
   expressions)
  #:transparent)

;; Export the following from the module:
(provide unity*
         declare*
         assign*
         ref*
         not*
         and*
         or*
         eq*
         multi-assignment*)

;; Example syntax
;; (unity* (list (declare* 0 'readwrite)
;;               (declare* 1 'write))
;;         (multi-assignment* '(1) '(#t))
;;         (list (assign* (ref* 0)
;;                        (multi-assignment* '(1)
;;                                           '((not* (ref* 0)))))))
