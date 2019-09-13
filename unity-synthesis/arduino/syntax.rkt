#lang rosette

(struct arduino* (setup loop) #:transparent)

(struct setup* (decl init) #:transparent)
(struct loop* (seq) #:transparent)

;; Expressions
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct eq* (left right) #:transparent)
(struct neq* (left right) #:transparent)
(struct not* (exp) #:transparent)
(struct read* (pin) #:transparent)
(struct ref* (var) #:transparent)

;; Setup Statements
(struct var* (ident) #:transparent)
(struct pin-mode* (pin mode) #:transparent)

;; Statements
(struct write!* (pin exp) #:transparent)
(struct set!* (var exp) #:transparent)
(struct if* (exp left) #:transparent)

;; Sequencing
(struct seq* (left right) #:transparent)

(provide arduino* setup* loop* and* or* eq* neq* not* read* ref* var* pin-mode* write!* set!* if* seq*)

;; Example syntax

(arduino* (setup* (seq* (var* 0)
                        (seq* (pin-mode* 0 'input)
                              (seq* (pin-mode* 1 'output)
                                    null)))
                  (seq* (set!* 0 #t)
                        (seq* (write!* 1 #f)
                              null)))
          (loop* (seq* (if* (eq* (read* 0)
                                 (ref* 0))
                            (seq* (set!* 0 (not* (ref* 0)))
                                  (seq* (write!* 1 (not* (read* 1)))
                                        null)))
                       null)))