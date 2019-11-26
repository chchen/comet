#lang rosette

(struct module*
  (name
   externals
   io-constraints
   type-declarations
   assignments)
  #:transparent)

(define (emit-externals externals)
  (string-join (map symbol->string externals) ", "))

;; IO Constraints
(struct input* (sym) #:transparent)
(struct output* (sym) #:transparent)

(define (emit-io io)
  (match io
    [(input* sym) (format "input ~a;" sym)]
    [(output* sym) (format "output ~a;" sym)]))

;; Type Declarations
(struct reg* (sym) #:transparent)
(struct wire* (sym) #:transparent)

(define (emit-decl decl)
  (match decl
    [(reg* sym) (format "reg ~a;" sym)]
    [(wire* sym) (format "wire ~a;" sym)]))

;; Assignments
(struct always*
  (sensitivity-list
   guarded-statements)
  #:transparent)

;; Event Expression
;; TODO: Add richer expression syntax (and, or)
(struct posedge* (sym) #:transparent)
(struct negedge* (sym) #:transparent)

(define (emit-event event)
  (match event
    [(posedge* sym) (format "posedge ~a" sym)]
    [(negedge* sym) (format "negedge ~a" sym)]))

(define (emit-sensitivity-list sensitivity-list)
  (string-join (map emit-event sensitivity-list) " or "))

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

(define (emit-expression expression)
  (match expression
    [(and* left right) (format "(~a && ~a)"
                               (emit-expression left)
                               (emit-expression right))]
    [(or* left right) (format "(~a || ~a)"
                              (emit-expression left)
                              (emit-expression right))]
    [(eq* left right) (format "(~a == ~a)"
                              (emit-expression left)
                              (emit-expression right))]
    [(neq* left right) (format "(~a != ~a)"
                               (emit-expression left)
                               (emit-expression right))]
    [(not* exp) (format "!~a"
                        (emit-expression exp))]
    [(val* sym) (symbol->string sym)]
    ['one "1"]
    ['zero "0"]))

(define (emit-block stmts)
    (list "begin"
          stmts
          "end"))
        
(define (emit-statements statements)
  (match statements
    ['() '()]
    [(cons (if* condition then-stmt else-stmt) tail)
     (let* ([condition-string (format "if (~a)" (emit-expression condition))]
            [then-strings (emit-statements then-stmt)]
            [then-block (emit-block then-strings)]
            [else-strings (emit-statements else-stmt)]
            [else-block (if (null? else-strings)
                            '()
                            (cons "else"
                                  (emit-block else-strings)))])
       (cons (list condition-string
                   then-block
                   else-block)
             (emit-statements tail)))]
     [(cons (<=* sym expression) tail)
      (cons (list (format "~a <= ~a;"
                          sym
                          (emit-expression expression)))
            (emit-statements tail))]))

(define (emit-assignments assignments)
  (match assignments
    ['() '()]
    [(cons (always* sensitivity-list
                    statements)
           tail)
     (let* ([statement-strings (emit-statements statements)]
            [statement-block (if (> (length statement-strings) 1)
                                 (emit-block statement-strings)
                                 statement-strings)])
       (cons (list (format "always @ (~a)" (emit-sensitivity-list sensitivity-list))
                   statement-block)
             (emit-assignments tail)))]))

(define (emit-module module)
  (match module
    [(module* name externals
       inputs-outputs
       type-declarations
       assignments)
     (list (format "module ~a(~a);" name (emit-externals externals))
           (append
            (map emit-io inputs-outputs)
            (map emit-decl type-declarations))
           (emit-assignments assignments)
           "endmodule")]))

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
         val*
         emit-module)

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


   
