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

;; Setup-only statements
(struct var* (ident) #:transparent)
(struct pin-mode* (pin mode) #:transparent)

;; Statements
(struct write!* (pin exp) #:transparent)
(struct set!* (var exp) #:transparent)
(struct if* (exp left) #:transparent)

;; Sequencing
(struct seq* (left right) #:transparent)

(define (seq-append left right)
  (match left
    [(seq* fst snd) (seq* fst (seq-append snd right))]
    ['() right]))

(provide arduino* setup* loop* and* or* eq* neq* not* read* ref* var* pin-mode* write!* set!* if* seq* seq-append)

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
;;                        null)))
