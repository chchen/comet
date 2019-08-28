#lang rosette

;; UNITY Syntax
(struct unity* (declare initially assign) #:transparent)

(struct declare* (variables) #:transparent)
(struct initially* (multi-assignment) #:transparent)
(struct assign* (guarded-assignments) #:transparent)

(struct multi* (variables expressions) #:transparent)
(struct clause* (guard multi clause) #:transparent)

;; Guard Expressions
(struct not* (exp) #:transparent)
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct eq* (left right) #:transparent)

;; Variable reference
(struct ref* (var) #:transparent)

(provide unity* declare* initially* assign* multi* clause* not* and* or* eq* ref*)

(unity* (declare* (list->vector '('read 'write)))
        (initially* (multi* '(1) '(#t)))
        (assign* (clause*
                  (ref* 0)
                  (multi* '(1) '((not* (ref* 0))))
                  null)))