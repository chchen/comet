#lang rosette/safe

(struct verilog-module*
  (name
   port-list
   declarations
   statements)
  #:transparent)

;; (define (emit-externals externals)
;;   (string-join (map symbol->string externals) ", "))

;; Port Declarations
(struct port-decl* (type-decl) #:transparent)
(struct input* port-decl* () #:transparent)
(struct output* port-decl* () #:transparent)

;; (define (emit-io io)
;;   (match io
;;     [(input* sym) (format "input ~a;" sym)]
;;     [(output* sym) (format "output ~a;" sym)]))

;; Type Declarations
(struct type-decl* (width ident) #:transparent)
(struct reg* type-decl* () #:transparent)
(struct wire* type-decl* () #:transparent)

;; (define (emit-decl decl)
;;   (match decl
;;     [(reg* sym) (format "reg ~a;" sym)]
;;     [(wire* sym) (format "wire ~a;" sym)]))

;; (define (emit-event event)
;;   (match event
;;     [(posedge* sym) (format "posedge ~a" sym)]
;;     [(negedge* sym) (format "negedge ~a" sym)]))

;; (define (emit-sensitivity-list sensitivity-list)
;;   (string-join (map emit-event sensitivity-list) " or "))

;; Statements
(struct always*
  (guard
   guarded-branch)
  #:transparent)

(struct if*
  (boolean-expression
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

;; (define (emit-expression expression)
;;   (match expression
;;     [(and* left right) (format "(~a && ~a)"
;;                                (emit-expression left)
;;                                (emit-expression right))]
;;     [(or* left right) (format "(~a || ~a)"
;;                               (emit-expression left)
;;                               (emit-expression right))]
;;     [(eq* left right) (format "(~a == ~a)"
;;                               (emit-expression left)
;;                               (emit-expression right))]
;;     [(neq* left right) (format "(~a != ~a)"
;;                                (emit-expression left)
;;                                (emit-expression right))]
;;     [(not* exp) (format "!~a"
;;                         (emit-expression exp))]
;;     [(val* sym) (symbol->string sym)]
;;     ['one "1"]
;;     ['zero "0"]))

;; (define (emit-block stmts)
;;     (list "begin"
;;           stmts
;;           "end"))

;; (define (emit-statements statements)
;;   (match statements
;;     ['() '()]
;;     [(cons (if* condition then-stmt else-stmt) tail)
;;      (let* ([condition-string (format "if (~a)" (emit-expression condition))]
;;             [then-strings (emit-statements then-stmt)]
;;             [then-block (emit-block then-strings)]
;;             [else-strings (emit-statements else-stmt)]
;;             [else-block (if (null? else-strings)
;;                             '()
;;                             (cons "else"
;;                                   (emit-block else-strings)))])
;;        (cons (list condition-string
;;                    then-block
;;                    else-block)
;;              (emit-statements tail)))]
;;      [(cons (<=* sym expression) tail)
;;       (cons (list (format "~a <= ~a;"
;;                           sym
;;                           (emit-expression expression)))
;;             (emit-statements tail))]))

;; (define (emit-assignments assignments)
;;   (match assignments
;;     ['() '()]
;;     [(cons (always* sensitivity-list
;;                     statements)
;;            tail)
;;      (let* ([statement-strings (emit-statements statements)]
;;             [statement-block (if (> (length statement-strings) 1)
;;                                  (emit-block statement-strings)
;;                                  statement-strings)])
;;        (cons (list (format "always @ (~a)" (emit-sensitivity-list sensitivity-list))
;;                    statement-block)
;;              (emit-assignments tail)))]))

;; (define (emit-module module)
;;   (string-join
;;    (flatten
;;     (match module
;;       [(module* name externals
;;          inputs-outputs
;;          type-declarations
;;          assignments)
;;        (list (format "module ~a(~a);" name (emit-externals externals))
;;              (append
;;               (map emit-io inputs-outputs)
;;               (map emit-decl type-declarations))
;;              (emit-assignments assignments)
;;              "endmodule")]))
;;    "\n"))

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

;; Example Syntax
;; (display
;;  (string-join
;;   (flatten
;;    (emit-module (module*
;;                     'foo
;;                     (list 'x 'y 'z 'clock 'reset)
;;                   (list (input* 'x)
;;                         (output* 'y)
;;                         (output* 'z)
;;                         (input* 'clock)
;;                         (input* 'reset))
;;                   (list (wire* 'x)
;;                         (reg* 'y)
;;                         (reg* 'z)
;;                         (wire* 'clock)
;;                         (wire* 'reset))
;;                   (list (always* (list (posedge* 'clock) (posedge* 'reset))
;;                                  (list (if* (val* 'reset)
;;                                             (list (<=* 'y 'zero)
;;                                                   (<=* 'z 'one))
;;                                             (list (if* (val* 'x)
;;                                                        (list (<=* 'y 'zero))
;;                                                        (list (<=* 'y 'one)))))))))))
;;   "\n"))
