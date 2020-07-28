#lang rosette/safe

(struct verilog-module*
  (name
   port-list
   declarations
   always)
  #:transparent)

;; Port Declarations
(struct port-decl* (type-decl) #:transparent)
(struct input* port-decl* () #:transparent)
(struct output* port-decl* () #:transparent)

;; Type Declarations
(struct type-decl* (width ident) #:transparent)
(struct reg* type-decl* () #:transparent)
(struct wire* type-decl* () #:transparent)

;; Always Construct
(struct always*
  (guard
   guarded-branch)
  #:transparent)

;; Statements
(struct if*
  (test-expr
   then-branch
   else-branch)
  #:transparent)

(struct <=* (sym expr) #:transparent)

;; Expression super structs
(struct unop* (expr) #:transparent)
(struct binop* (left right) #:transparent)

;; Event Expressions
(struct posedge* unop* () #:transparent)
(struct negedge* unop* () #:transparent)

;; Type conversions
(struct bool->vect* unop* () #:transparent)

;; Expressions
;; bool -> bool
(struct not* unop* () #:transparent)
;; vector -> vector
(struct bwnot* unop* () #:transparent)
;; bool -> bool -> bool
(struct and* binop* () #:transparent)
(struct or* binop* () #:transparent)
(struct eq* binop* () #:transparent)
;; vector -> vector -> bool
(struct bweq* binop* () #:transparent)
(struct lt* binop* () #:transparent)
;; vector -> vector -> vector
(struct bwand* binop* () #:transparent)
(struct bwor* binop* () #:transparent)
(struct bwxor* binop* () #:transparent)
(struct shl* binop* () #:transparent)
(struct shr* binop* () #:transparent)
(struct add* binop* () #:transparent)

(provide verilog-module*
         port-decl*
         input*
         output*
         type-decl*
         type-decl*-width
         type-decl*-ident
         reg*
         wire*
         always*
         posedge*
         negedge*
         if*
         <=*
         unop*
         binop*
         bool->vect*
         not*
         bwnot*
         and*
         or*
         eq*
         bweq*
         lt*
         bwand*
         bwor*
         bwxor*
         shl*
         shr*
         add*)
