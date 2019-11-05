#lang rosette

(struct module*
  (name
   externals
   io-constraints
   type-declarations
   assignments)
  #:transparent)

;; IO Constraints
(struct input* (sym) #:transparent)
(struct output* (sym) #:transparent)

;; Type Declarations
(struct reg* (sym) #:transparent)
(struct wire* (sym) #:transparent)

;; Assignments
(struct always*
  (sensitivity-list
   guarded-statements)
  #:transparent)

;; Event Expression
;; TODO: Add richer expression syntax (and, or)
(struct posedge* (sym) #:transparent)
(struct negedge* (sym) #:transparent)

;; Statements
(struct if*
  (boolean-expression
   then-statement
   else-statement)
  #:transparent)

(struct <=* (sym expression) #:transparent)

;; Expressions
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct eq* (left right) #:transparent)
(struct neq* (left right) #:transparent)
(struct not* (expression) #:transparent)
(struct val* (sym) #:transparent)

(provide module*
         input*
         output*
         reg*
         wire*
         always*
         posedge*
         negedge*
         if*
         <=*
         and*
         or*
         eq*
         neq*
         not*
         val*)

;; Example Syntax
;; (verilog-module*
;;  'foo
;;  (list 'x 'y 'clock 'reset)
;;  (list (input* 'x)
;;        (output* 'y)
;;        (input* 'clock)
;;        (input* 'reset))
;;  (list (wire* 'x)
;;        (reg* 'y)
;;        (wire* 'clock)
;;        (wire* 'reset))
;;  (list (always* (list (posedge* 'clock))
;;                 (list (if* (val* 'x)
;;                            (list (<=* 'y 0))
;;                            (list (<=* 'y 1)))))
;;        (always* (list (posedge* 'reset))
;;                 (list (<=* 'y 0)))))


   
