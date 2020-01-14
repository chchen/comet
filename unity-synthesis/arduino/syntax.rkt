#lang rosette

(struct arduino* (setup loop) #:transparent)

(struct setup* (statements) #:transparent)
(struct loop* (statements) #:transparent)

;; Expressions
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct eq* (left right) #:transparent)
(struct neq* (left right) #:transparent)
(struct not* (exp) #:transparent)
(struct read* (pin) #:transparent)
(struct ref* (var) #:transparent)

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
    [(not* exp) (format "!~a" (emit-expression exp))]
    [(read* pin) (format "digitalRead(~a)" pin)]
    [(ref* var) var]
    ['true "HIGH"]
    ['false "LOW"]))

;; Setup-only statements
(struct var* (ident) #:transparent)
(struct pin-mode* (pin mode) #:transparent)

;; Statements
(struct write!* (pin exp) #:transparent)
(struct set!* (var exp) #:transparent)
(struct if* (exp left) #:transparent)

;; Sequencing
(define (emit-block block)
  (list "{"
        block
        "}"))

(define (emit-statements statements)
  (match statements
    ['() '()]
    [(cons fst snd)
     (let ([fst-strings            
            (match fst
              [(var* ident) (format "int ~a;" ident)]
              [(pin-mode* ident mode) (format "pinMode(~a, ~a);"
                                              ident
                                              (if (eq? mode 'input)
                                                  "INPUT"
                                                  "OUTPUT"))]
              [(write!* pin exp) (format "digitalWrite(~a, ~a);"
                                         pin
                                         (emit-expression exp))]
              [(set!* var exp) (format "~a = ~a;"
                                       var
                                       (emit-expression exp))]
              [(if* exp left) (list (format "if (~a)" (emit-expression exp))
                                    (emit-block (emit-statements left)))])])
       (cons fst-strings (emit-statements snd)))]))

(define (emit-program program)
  (string-join
   (flatten
    (match program
      [(arduino* (setup* setup)
                 (loop* loop))
       (list "void setup()"
             (emit-block (emit-statements setup))
             "void loop()"
             (emit-block (emit-statements loop)))]))
   "\n" #:after-last "\n"))

(provide arduino* setup* loop* and* or* eq* neq* not* read* ref* var* pin-mode* write!* set!* if* emit-program)

;; Example syntax
;; (arduino* (setup* (seq* (var* 'x)
;;                         (seq* (pin-mode* 0 'input)
;;                               (seq* (pin-mode* 1 'output)
;;                                     (seq* (set!* 'x 'true)
;;                                           (seq* (write!* 1 'false)
;;                                                 null))))))
;;           (loop* (seq* (if* (eq* (read* 0)
;;                                  (ref* 'x))
;;                             (seq* (set!* 'x (not* (ref* 'x)))
;;                                   (seq* (write!* 1 (not* (read* 1)))
;;                                         null)))
;;                        null))))
