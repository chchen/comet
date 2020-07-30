#lang rosette/safe

(require "../util.rkt"
         "environment.rkt"
         "syntax.rkt"
         rosette/lib/match
         ;; unsafe! be sure you know what you're doing
         ;; when you use the following
         (only-in racket/base
                  random
                  symbol?))

(struct guard-trace
  (guard
   trace)
  #:transparent)

(define (external? typ)
  (case typ
    ['boolean #f]
    ['natural #f]
    ['recv-channel #t]
    ['send-channel #t]
    ['recv-buf #f]
    ['send-buf #f]))

(define (internal? typ)
  (case typ
    ['boolean #t]
    ['natural #t]
    ['recv-channel #f]
    ['send-channel #f]
    ['recv-buf #t]
    ['send-buf #t]))

(define (context->external-vars cxt)
  (keys (filter (lambda (pair)
                  (external? (cdr pair)))
                cxt)))

(define (context->internal-vars cxt)
  (keys (filter (lambda (pair)
                  (internal? (cdr pair)))
                cxt)))

(define (natural? n)
  (and (integer? n)
       (not (negative? n))))

(define (eval-not v)
  (not v))

(define (eval-and l r)
  (and l r))

(define (eval-or l r)
  (or l r))

(define (eval-+ l r)
  (+ l r))

(define (eval-< l r)
  (< l r))

(define (eval-= l r)
  (= l r))

(define (eval-message val)
  (channel* #t val))

(define (eval-send-buf-empty? buf)
  (match buf
    [(buffer* sent vals)
     (>= sent (length vals))]))

(define (eval-recv-buf-full? buf)
  (match buf
    [(buffer* rcvd vals)
     (>= rcvd (length vals))]))

;; Stores a natural number as a new send-buffer
;; Number is stored as a little-endian list of booleans
(define (eval-nat->send-buf len val)
  (let ([bools (map bitvector->bool
                    (bitvector->bits
                     (integer->bitvector val
                                         (bitvector len))))])
    (buffer* 0 bools)))

;; Retrieves the "next" boolean from a send-buffer
;; Buffer data is stored as a little-endian list of booleans
(define (eval-send-buf-get buf)
  (match buf
    [(buffer* sent vals)
     (list-ref vals sent)]))

;; Increment cursor for send-buffer
;; Resultant cursor increments one significant place
(define (eval-send-buf-next buf)
  (match buf
    [(buffer* sent vals)
     (buffer* (add1 sent) vals)]))

(define (false-list len)
  (if (zero? len)
      '()
      (cons #f (false-list (sub1 len)))))

(define (eval-empty-recv-buf len)
  (buffer* 0 (false-list len)))

(define (eval-empty-send-buf len)
    (buffer* len (false-list len)))

;; Buffer is a "little endian" list of values
;; when cursor is at 0, we insert at the least significant
;; when cursor is maxed out, we insert at the most significant
;; increment cursor
(define (eval-recv-buf-put buf item)
  (define (insert-list dist item lst)
    (if (null? lst)
        '()
        (cons (if (zero? dist)
                  item
                  (car lst))
              (insert-list (sub1 dist) item (cdr lst)))))

  (match buf
    [(buffer* rcvd vals)
     (buffer* (add1 rcvd) (insert-list rcvd item vals))]))

;; Transforms a full recv-buffer into a natural number
;; Note that 'concat' works on "big endian" lists
;; so we must reverse the incoming list of bitbectors
(define (eval-recv-buf->nat buf)
  (match buf
    [(buffer* rcvd vals)
     (bitvector->natural
      (apply concat
             (reverse (map bool->bitvector vals))))]))

;; Evaluate an expression. Takes an expression, context, and a state
(define (evaluate-expr expression context state-object)
  (match state-object
    [(stobj state)
     (define (unary next-func expr)
       (let ([val (eval-helper expr)])
         (next-func val)))

     (define (binary next-func expr-l expr-r)
       (let ([val-l (eval-helper expr-l)]
             [val-r (eval-helper expr-r)])
         (next-func val-l val-r)))

     (define (eval-helper expr)
       (match expr
         ;; Boolean -> Boolean Expressions
         [(not* e) (unary eval-not e)]
         [(and* l r) (binary eval-and l r)]
         [(or* l r) (binary eval-or l r)]
         [(eq* l r) (eval-helper (or* (and* l r) (and* (not* l) (not* r))))]
         ;; Nat x Nat -> Nat Expressions
         [(+* l r) (binary eval-+ l r)]
         ;; Nat x Nat -> Boolean Expressions
         [(<* l r) (binary eval-< l r)]
         [(=* l r) (binary eval-= l r)]
         ;; Channel Expressions
         [(message* e) (unary eval-message e)]
         ;; Buffer -> Boolean Predicates
         [(send-buf-empty?* b) (unary eval-send-buf-empty? b)]
         [(recv-buf-full?* b) (unary eval-recv-buf-full? b)]
         ;; Buffer Expressions
         [(nat->send-buf* l v) (binary eval-nat->send-buf l v)]
         [(empty-recv-buf* l) (unary eval-empty-recv-buf l)]
         [(empty-send-buf* l) (unary eval-empty-send-buf l)]
         [(recv-buf-put* b v) (binary eval-recv-buf-put b v)]
         [(recv-buf->nat* b) (unary eval-recv-buf->nat b)]
         [(send-buf-get* b) (unary eval-send-buf-get b)]
         [(send-buf-next* b) (unary eval-send-buf-next b)]
         ;; Symbol |- *-Channel -> Boolean Predicates
         [(full?* id) (for/all ([val (get-mapping id state)])
                               (channel*-valid val))]
         [(empty?* id) (for/all ([val (get-mapping id state)])
                                (not (channel*-valid val)))]
         ;; Symbol |- Recv-Channel -> Boolean Deconstructor
         [(value* id) (for/all ([val (get-mapping id state)])
                               (channel*-value val))]
         ;; Terminals
         [term
          (cond
            ;; 'empty reserved word
            [(eq? term 'empty) (channel* #f null)]
            ;; boolean literals
            [(boolean? term) term]
            ;; natural numbers
            [(natural? term) term]
            ;; all other symbols are variable references
            [(symbol? expr) (get-mapping expr state)])]))

     (eval-helper expression)]))

;; Interpret an assignment statement
;;
;; Apply the expression values to the corresponding variables, given a context
;; and start state. Expression values are with respect to the given start
;; state, not to any intermediate state.
;;
;; For conditional (case*) assignments, we apply the expression values if the
;; boolean expression guard is satisified. If no guards are satisified, then the
;; start state is returned.
(define (interpret-assign-stmts assignments context state-object)
  (match state-object
    [(stobj state)

     (define (build-trace vars exprs)
       (map (lambda (v e)
              (cons v
                    (evaluate-expr e context state-object)))
            vars
            exprs))

     (define (expand-cases vars cases)
       (map (lambda (c)
              (let ([exps (car c)]
                    [guard (cdr c)])
                (guard-trace (evaluate-expr guard context state-object)
                             (build-trace vars exps))))
            cases))

     (define (regularize-assign assign)
       (match assign
         [(:=* vars exps)
          (match exps
            [(case* cases) (expand-cases vars cases)]
            [_ (guard-trace #t
                            (build-trace vars exps))])]))

     (define (apply-traces traces)
       (match traces
         ['() (stobj state)]
         [(cons head tail)
          (match head
            [(guard-trace guard? trace)
             (if guard?
                 (stobj (append trace state))
                 (apply-traces tail))])]))

     (let* ([guard-traces (flatten (map regularize-assign assignments))])
       (apply-traces guard-traces))]))

;; Interpret the declaration clause. This just means taking adding the name to
;; type mapping and constructing a new environment. Takes an initial state.
(define (interpret-declare program stobj)
  (match program
    [(unity* declare _ _)
     (match declare
       [(declare* context)
        (environment* context stobj)])]))

;; Interpret the initially cause, given an existing environment with a context
;; and a state
(define (interpret-initially program env)
  (match program
    [(unity* _ initially _)
     (match initially
       [(initially* assignment)
        (match env
          [(environment* cxt stobj)
           (environment*
            cxt
            (interpret-assign-stmts assignment cxt stobj))])])]))

;; Interpret the assign clause, given an existing environment with a context and
;; a state
(define (interpret-assign program env)
  (define (pick-stmts stmts)
    (if (null? stmts)
        '()
        (list-ref stmts (random (length stmts)))))

  (match program
    [(unity* _ _ assign-section)
     (match assign-section
       [(assign* assignments)
        (match env
          [(environment* cxt stobj)
           (let ([chosen-assignment (pick-stmts assignments)])
             (environment*
              cxt
              (interpret-assign-stmts chosen-assignment cxt stobj)))])])]))

(provide context->external-vars
         context->internal-vars
         evaluate-expr
         interpret-declare
         interpret-initially
         interpret-assign)

;; Tests

(assert
 (let* ([initial-state (stobj
                        (list (cons 'out (channel* #f null))
                              (cons 'in (channel* #t #t))))]
        [prog unity-example-program]
        [env (interpret-declare prog initial-state)]
        [env2 (interpret-initially prog env)]
        [env3 (interpret-assign prog env2)])
   (and (environment*? env)
        (environment*? env2)
        (environment*? env3))))

;; Assert that send-buf and recv-buf conversions work

(current-bitwidth 8)
(define-symbolic N integer?)
(define (transfer-buf from to)
  (if (eval-send-buf-empty? from)
      to
      (transfer-buf
       (eval-send-buf-next from)
       (eval-recv-buf-put to
                          (eval-send-buf-get from)))))

(assert
 (unsat?
  (let* ([word-size 8]
         [send-buffer (eval-nat->send-buf word-size N)]
         [empty-recv-buf (eval-empty-recv-buf word-size)]
         [recv-buffer (transfer-buf send-buffer empty-recv-buf)]
         [recv-nat (eval-recv-buf->nat recv-buffer)])
    (verify
     #:assume (assert
               (and (<= 0 N)
                    (< N (expt 2 word-size))))
     #:guarantee (assert (= N recv-nat))))))
