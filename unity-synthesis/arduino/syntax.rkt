#lang rosette/safe

(struct arduino* (setup loop) #:transparent)
(struct setup* (statements) #:transparent)
(struct loop* (statements) #:transparent)

;; In the Arduino model, internal state is represented
;; in 8-bit unsigned bitvectors

;; Traditional "Boolean" Expressions
;; Bitvector -> Bitvector
(struct not* (expr) #:transparent)
;; Bitvector -> Bitvector -> Bitvector
(struct and* (left right) #:transparent)
(struct or* (left right) #:transparent)
(struct lt* (left right) #:transparent)
(struct eq* (left right) #:transparent)

;; Traditional "Bitvector/Bitwise" Expressions
;; Bitvector -> Bitvector
(struct bwnot* (left) #:transparent)
;; Bitvector -> Bitvector -> Bitvector
(struct add* (left right) #:transparent)
(struct bwand* (left right) #:transparent)
(struct bwor* (left right) #:transparent)
(struct bwxor* (left right) #:transparent)
(struct shl* (bitvector shift-by) #:transparent)
(struct shr* (bitvector shift-by) #:transparent)

;; Input
;; Symbol -> Bitvector Expression
;; Read returns 0x1 (true) or 0x0 (false)
(struct read* (pin) #:transparent)

;; Setup-only statements
;; Symbol -> Unit
(struct byte* (ident) #:transparent)
(struct unsigned-int* (ident) #:transparent)

;; Symbol -> Symbol -> Unit
(struct pin-mode* (pin mode) #:transparent)

;; Output
;; Symbol -> Bitvector -> Unit
;; Pins hold boolean values, so write coerces 0x0 -> false, true otherwise
(struct write* (pin expr) #:transparent)

;; Variable
;; Symbol -> Bitvector -> Unit
(struct :=* (var expr) #:transparent)

;; Conditional Execution
;; Bitvector -> Unit -> Unit -> Unit
(struct if* (test left right) #:transparent)

(provide arduino*
         setup*
         setup*-statements
         loop*
         loop*-statements
         not*
         and*
         or*
         lt*
         eq*
         bwnot*
         add*
         bwand*
         bwor*
         bwxor*
         shl*
         shr*
         read*
         byte*
         unsigned-int*
         pin-mode*
         write*
         :=*
         if*)
