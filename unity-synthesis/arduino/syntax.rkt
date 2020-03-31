#lang rosette

(struct arduino* (setup loop) #:transparent)
(struct setup* (statements) #:transparent)
(struct loop* (statements) #:transparent)

;; In the Arduino model, internal state is represented
;; in 8-bit unsigned bitvectors

;; Traditional "Boolean" Expressions
;; Byte -> Byte
(struct not* (expr) #:transparent)
;; Byte -> Byte -> Byte
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct le* (left right) #:transparent)
(struct eq* (left right) #:transparent)

;; Traditional "Byte/Bitwise" Expressions
;; Byte -> Byte -> Byte
(struct add* (left right) #:transparent)
(struct bwand* (left right) #:transparent)
(struct bwor* (left right) #:transparent)
;; Byte -> Nat -> Byte
(struct shl* (byte bits) #:transparent)
(struct shr* (byte bits) #:transparent)

;; Input
;; Symbol -> Byte Expression
;; Bytes are coerced into 0x0 or 0x1 false/true, low/high values
(struct read* (pin) #:transparent)


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
;;     [(not* exp) (format "!~a" (emit-expression exp))]
;;     [(read* pin) (format "digitalRead(~a)" pin)]
;;     [(ref* var) var]
;;     ['true "HIGH"]
;;     ['false "LOW"]))

;; Setup-only statements
;; Symbol -> Unit
(struct byte* (ident) #:transparent)

;; Symbol -> Symbol -> Unit
(struct pin-mode* (pin mode) #:transparent)

;; Output
;; Symbol -> Byte -> Unit
;; Bytes are coerced into 0x0 or 0x1 false/true, low/high values
(struct write* (pin exp) #:transparent)

;; Variable
;; Symbol -> Byte -> Unit
(struct :=* (var exp) #:transparent)

;; Conditional Execution
;; Byte -> Unit -> Unit -> Unit
(struct if* (cond left right) #:transparent)

;; Sequencing
;; (define (emit-block block)
;;   (list "{"
;;         block
;;         "}"))

;; (define (emit-statements statements)
;;   (match statements
;;     ['() '()]
;;     [(cons fst snd)
;;      (let ([fst-strings
;;             (match fst
;;               [(var* ident) (format "int ~a;" ident)]
;;               [(pin-mode* ident mode) (format "pinMode(~a, ~a);"
;;                                               ident
;;                                               (if (eq? mode 'input)
;;                                                   "INPUT"
;;                                                   "OUTPUT"))]
;;               [(write!* pin exp) (format "digitalWrite(~a, ~a);"
;;                                          pin
;;                                          (emit-expression exp))]
;;               [(set!* var exp) (format "~a = ~a;"
;;                                        var
;;                                        (emit-expression exp))]
;;               [(if* exp left) (list (format "if (~a)" (emit-expression exp))
;;                                     (emit-block (emit-statements left)))])])
;;        (cons fst-strings (emit-statements snd)))]))

;; (define (emit-program program)
;;   (string-join
;;    (flatten
;;     (match program
;;       [(arduino* (setup* setup)
;;                  (loop* loop))
;;        (list "void setup()"
;;              (emit-block (emit-statements setup))
;;              "void loop()"
;;              (emit-block (emit-statements loop)))]))
;;    "\n" #:after-last "\n"))

(provide arduino*
         setup*
         loop*
         not*
         and*
         or*
         le*
         eq*
         add*
         bwand*
         bwor*
         shl*
         shr*
         read*
         byte*
         pin-mode*
         write*
         :=*
         if*)

;; Example syntax
;; (arduino* (setup*
;;            (list (byte* 'x)
;;                  (pin-mode* 'd0 'input)
;;                  (pin-mode* 'd1 'output)
;;                  (:=* 'x 'true)
;;                  (write* '1 'LOW)))
;;           (loop*
;;            (list (if* (and* (eq* (read* '0) 'HIGH)
;;                             'x)
;;                       (list (:=* 'x 'false)
;;                             (write* 'd1 'HIGH))
;;                       '()))))
