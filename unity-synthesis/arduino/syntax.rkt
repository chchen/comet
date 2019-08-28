#lang rosette

;; Expressions
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct eq* (left right) #:transparent)
(struct neq* (left right) #:transparent)
(struct not* (exp) #:transparent)
(struct read* (pin) #:transparent)
(struct ref* (var) #:transparent)

;; Statements
(struct write!* (pin exp) #:transparent)
(struct set!* (var exp) #:transparent)
(struct if* (exp left) #:transparent)

;; Sequencing
(struct seq* (left right) #:transparent)

(provide and* or* eq* neq* not* read* ref* write!* set!* if* seq*)