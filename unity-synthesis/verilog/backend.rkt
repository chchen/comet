#lang rosette/safe

(require "syntax.rkt"
         "../bool-bitvec/types.rkt"
         "../util.rkt"
         rosette/lib/match
         (only-in racket/string string-join)
         (only-in racket/base symbol->string))

(define (print-verilog-module mod)
  (display
   (string-join
    (flatten
     (pretty-indent (emit-verilog-module mod) ""))
    "\n"
    #:after-last "\n")))

(define (emit-verilog-module mod)
  (match mod
    [(verilog-module* name ports decls always)
     (let ([port-list-str (string-join (map symbol->string ports)
                                       ",")])
       (list (format "module ~a(~a);" name port-list-str)
             (map emit-decl decls)
             (map emit-always always)
             "endmodule"))]))

(define (emit-decl decl)
  (format "~a;"
          (match decl
            [(port-decl* _) (emit-port-decl decl)]
            [(type-decl* _ _) (emit-type-decl decl)])))

(define (emit-port-decl decl)
  (match decl
    [(port-decl* type-decl)
     (let ([type-decl-str (emit-type-decl type-decl)])
       (match decl
         [(input* decl) (format "input ~a" type-decl-str)]
         [(output* decl) (format "output ~a" type-decl-str)]))]))

(define (emit-type-decl decl)
  (match decl
    [(reg* width ident)
     (if (= width 1)
         (format "reg ~a" ident)
         (format "reg[~a:0] ~a" (sub1 width) ident))]
    [(wire* width ident)
     (if (= width 1)
         (format "wire ~a" ident)
         (format "wire[~a:0] ~a" (sub1 width) ident))]))

(define (emit-always always)
  (match always
    [(always* trigger branch)
     (let ([trigger-str (emit-trigger trigger)]
           [branch-str (emit-stmts branch)])
       (cons (format "always @(~a)" trigger-str)
             branch-str))]))

(define (emit-stmts stmts)
  (define (helper s)
    (if (null? s)
        (list "end")
        (match (car s)
          [(if* test-expr then-br else-br)
           (append (emit-if test-expr then-br else-br)
                   (helper (cdr s)))]
          [(<=* sym expr)
           (cons (emit-<= sym expr)
                 (helper (cdr s)))])))

  (cons "begin"
        (helper stmts)))

(define (emit-if test-expr then-br else-br)
  (let ([test-str (emit-expr test-expr)]
        [then-str (emit-stmts then-br)])
    (if (null? else-br)
        (list (format "if (~a)" test-str)
              then-str)
        (let ([else-str (emit-stmts else-br)])
          (list (format "if (~a)" test-str)
                then-str
                "else"
                else-str)))))

(define (emit-<= sym expr)
  (let ([expr-str (emit-expr expr)])
    (format "~a <= ~a;" sym expr-str)))

(define (emit-expr expr)
  (match expr
    [(unop* l)
     (let ([l-str (emit-expr l)])
       (match expr
         [(posedge* _) (format "posdege ~a" l-str)]
         [(negedge* _) (format "negedge ~a" l-str)]
         [(bool->vect* _) l-str]
         [(not* _) (format "!~a" l-str)]
         [(bwnot* _) (format "~~~a" l-str)]))]
    [(binop* l r)
     (let ([l-str (emit-expr l)]
           [r-str (emit-expr r)])
       (match expr
         [(and* _ _) (format "(~a && ~a)" l-str r-str)]
         [(or* _ _) (format "(~a || ~a)" l-str r-str)]
         [(eq* _ _) (format "(~a == ~a)" l-str r-str)]
         [(bweq* _ _) (format "(~a == ~a)" l-str r-str)]
         [(lt* _ _) (format "(~a < ~a)" l-str r-str)]
         [(bwand* _ _) (format "(~a & ~a)" l-str r-str)]
         [(bwor* _ _) (format "(~a | ~a)" l-str r-str)]
         [(bwxor* _ _) (format "(~a ^ ~a)" l-str r-str)]
         [(shl* _ _) (format "(~a << ~a)" l-str r-str)]
         [(shr* _ _) (format "(~a >> ~a)" l-str r-str)]
         [(add* _ _) (format "(~a + ~a)" l-str r-str)]))]
    [t (format "~a"
               (cond
                 [(vect? t) (bitvector->natural t)]
                 [(boolean? t) (if t 1 0)]
                 [else t]))]))

(define (emit-trigger expr)
  (match expr
    [(unop* l)
     (let ([l-str (emit-trigger l)])
       (match expr
         [(posedge* _) (format "posedge ~a" l-str)]
         [(negedge* _) (format "negedge ~a" l-str)]))]
    [(binop* l r)
     (let ([l-str (emit-trigger l)]
           [r-str (emit-trigger r)])
       (match expr
         [(or* _ _) (format "~a or ~a" l-str r-str)]))]
    [e (format "~a" e)]))

;; (print-verilog-module
;;  (verilog-module*
;;   'test
;;   (list 'in 'out 'clock 'reset)
;;   (list (input* (wire* 1 'in))
;;         (output* (reg* 1 'out))
;;         (input* (wire* 1 'clock))
;;         (input* (wire* 1 'reset)))
;;   (list (always* (or* (posedge* 'clock)
;;                       (posedge* 'reset))
;;                  (list (if* 'reset
;;                             (list (<=* 'out #f))
;;                             (list (<=* 'out (bwnot* 'in)))))))))

(provide print-verilog-module)
