#lang rosette/safe

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
(struct lt* (left right) #:transparent)
(struct eq* (left right) #:transparent)

;; Traditional "Byte/Bitwise" Expressions
;; Byte -> Byte
(struct bwnot* (left) #:transparent)
;; Byte -> Byte -> Byte
(struct add* (left right) #:transparent)
(struct bwand* (left right) #:transparent)
(struct bwor* (left right) #:transparent)
(struct bwxor* (left right) #:transparent)
(struct shl* (byte shift-by) #:transparent)
(struct shr* (byte shift-by) #:transparent)

;; Input
;; Symbol -> Byte Expression
;; Read returns 0x1 (true) or 0x0 (false)
(struct read* (pin) #:transparent)

;; Setup-only statements
;; Symbol -> Unit
(struct byte* (ident) #:transparent)

;; Symbol -> Symbol -> Unit
(struct pin-mode* (pin mode) #:transparent)

;; Output
;; Symbol -> Byte -> Unit
;; Pins hold boolean values, so write coerces 0x0 -> false, true otherwise
(struct write* (pin expr) #:transparent)

;; Variable
;; Symbol -> Byte -> Unit
(struct :=* (var expr) #:transparent)

;; Conditional Execution
;; Byte -> Unit -> Unit -> Unit
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
         pin-mode*
         write*
         :=*
         if*)
