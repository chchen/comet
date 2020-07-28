#lang rosette/safe

(require "bitvector.rkt"
         "syntax.rkt"
         "../util.rkt"
         rosette/lib/match
         (only-in racket/string string-join)
         (only-in racket/base symbol->string substring))

(define (print-arduino-program program)
  (display
   (string-join
    (flatten
     (pretty-indent (emit-arduino-program program) ""))
    "\n"
    #:after-last "\n")))

(define (emit-arduino-program program)
  (match program
    [(arduino* setup loop)
     (let* ([setup-stmts (setup*-statements setup)]
            [loop-stmts (loop*-statements loop)]
            [var-decls (setup->var-decls setup-stmts)]
            [pins-inits (setup->pins-inits setup-stmts)])
       (append (emit-stmts var-decls)
               (list
                "void setup()"
                (emit-block pins-inits)
                "void loop()"
                (emit-block loop-stmts))))]))

(define (setup->var-decls setup)
  (define (var-stmt? stmt)
    (match stmt
      [(byte* _) #t]
      [_ #f]))

  (filter var-stmt? setup))

(define (setup->pins-inits setup)
  (define (pins-inits-stmt? stmt)
    (match stmt
      [(byte* _) #f]
      [_ #t]))

  (filter pins-inits-stmt? setup))

(define (emit-block stmts)
  (if (null? stmts)
      '()
      (list "{"
            (emit-stmts stmts)
            "}")))

(define (emit-stmts stmts)
  (define (emit-stmt stmt)
    (match stmt
      [(byte* ident) (format "byte ~a;" ident)]
      [(pin-mode* pin mode) (format "pinMode(~a, ~a);"
                                    (pin-id pin)
                                    (if (eq? mode 'input)
                                        "INPUT"
                                        "OUTPUT"))]
      [(write* pin expr) (format "digitalWrite(~a, ~a);"
                                 (pin-id pin)
                                 (emit-expr expr))]
      [(:=* var expr) (format "~a = ~a;"
                              var
                              (emit-expr expr))]
      [(if* test left right) (if (null? right)
                                 (list
                                  (format "if (~a)" (emit-expr test))
                                  (emit-block left))
                                 (list
                                  (format "if (~a)" (emit-expr test))
                                  (emit-block left)
                                  (cons "else"
                                        (emit-block right))))]))

  (map emit-stmt stmts))

(define (emit-expr expr)
  (match expr
    [(not* e) (format "!~a" (emit-expr e))]
    [(and* l r) (format "(~a && ~a)" (emit-expr l) (emit-expr r))]
    [(or* l r) (format "(~a || ~a)" (emit-expr l) (emit-expr r))]
    [(lt* l r) (format "(~a < ~a)" (emit-expr l) (emit-expr r))]
    [(eq* l r) (format "(~a == ~a)" (emit-expr l) (emit-expr r))]
    [(bwnot* e) (format "~~~a" (emit-expr e))]
    [(add* l r) (format "(~a + ~a)" (emit-expr l) (emit-expr r))]
    [(bwand* l r) (format "(~a & ~a)" (emit-expr l) (emit-expr r))]
    [(bwor* l r) (format "(~a | ~a)" (emit-expr l) (emit-expr r))]
    [(bwxor* l r) (format "(~a ^ ~a)" (emit-expr l) (emit-expr r))]
    [(shl* l r) (format "(~a << ~a)" (emit-expr l) (emit-expr r))]
    [(shr* l r) (format "(~a >> ~a)" (emit-expr l) (emit-expr r))]
    [(read* e) (format "digitalRead(~a)" (pin-id e))]
    [t (format "~a"
               (cond
                 [(word? t) (bitvector->natural t)]
                 [else t]))]))

(define (pin-id id)
  (substring (symbol->string id) 1))

(provide print-arduino-program)

;; (print-arduino-program
;;  (arduino* (setup*
;;             (list (byte* 'x)
;;                   (pin-mode* 'd0 'input)
;;                   (pin-mode* 'd1 'output)
;;                   (:=* 'x 'true)
;;                   (write* 'd1 'LOW)))
;;            (loop*
;;             (list (if* (and* (eq* (read* 'd0) 'HIGH)
;;                              'x)
;;                        (list (:=* 'x 'false)
;;                              (write* 'd1 'HIGH))
;;                        (list (:=* 'x 'false)
;;                              (write* 'd1 'HIGH))
;;                        )))))
