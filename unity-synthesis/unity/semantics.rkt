#lang rosette/safe

(require "../util.rkt"
         "environment.rkt"
         "syntax.rkt"
         rosette/lib/match
         ;; unsafe! only allowed for concrete evaluation
         (only-in racket/base
                  random
                  symbol?))

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
  (= (send-buf*-sent buf)
     (length (send-buf*-vals buf))))

(define (eval-recv-buf-full? buf)
  (= (recv-buf*-rcvd buf)
     (length (recv-buf*-vals buf))))

(define (eval-nat->send-buf len val)
  (define (nat->bool-list v pow)
    (if (< pow 0) ;; base case
        '()
        (let ([e (expt 2 pow)])
          (if (>= v e)
              (cons #t (nat->bool-list (- v e)
                                       (sub1 pow)))
              (cons #f (nat->bool-list v
                                       (sub1 pow)))))))

  (let ([maxval (sub1 (expt 2 len))])
    (if (> val maxval)
        'send-buf-overflow
        (send-buf* 0 (nat->bool-list val (sub1 len))))))

(define (eval-send-buf-get buf)
  (define (walk-list dist lst)
    (if (<= dist 0)
        (car lst)
        (walk-list (sub1 dist) (cdr lst))))

  (match buf
    [(send-buf* sent vals)
     (if (>= sent (length vals))
         'send-buf-empty
         (walk-list sent vals))]))

(define (eval-send-buf-next buf)
  (match buf
    [(send-buf* sent vals)
     (if (>= sent (length vals))
         'send-buf-empty
         (send-buf* (add1 sent) vals))]))

(define (eval-empty-recv-buf len)
  (define (false-list dist)
    (if (<= dist 0)
        '()
        (cons #f (false-list (sub1 dist)))))

  (recv-buf* 0 (false-list len)))

(define (eval-recv-buf-put buf item)
  (define (insert-list dist item lst)
    (if (null? lst)
        '()
        (if (= dist 0)
            (cons item
                  (insert-list (sub1 dist) item (cdr lst)))
            (cons (car lst)
                  (insert-list (sub1 dist) item (cdr lst))))))

  (match buf
    [(recv-buf* rcvd vals)
     (if (>= rcvd (length vals))
         'recv-buf-full
         (recv-buf* (add1 rcvd) (insert-list rcvd item vals)))]))

(define (eval-recv-buf->nat buf)
  (define (bool-list->nat l pow)
    (if (null? l)
        0
        (let ([e (expt 2 pow)]
              [head (car l)]
              [tail (cdr l)])
          (if head
              (+ e (bool-list->nat tail (+ 1 pow)))
              (bool-list->nat tail (+ 1 pow))))))

  (match buf
    [(recv-buf* rcvd vals)
     (if (< rcvd (length vals))
         'recv-buf-not-full
         (bool-list->nat vals 0))]))

;; Evaluate an expression. Takes an expression, context, and a state
(define (evaluate-expr expression context state)
  (define (type-check? id val)
    (case (get-mapping id context)
      ['boolean (boolean? val)]
      ['natural (natural? val)]
      ['recv-channel (channel*? val)]
      ['send-channel (channel*? val)]
      ['recv-buf (recv-buf*? val)]
      ['send-buf (send-buf*? val)]
      [else #f]))

  (define (unary predicate next-func expr error-symbol)
    (let ([val (eval-helper expr)])
      (if (predicate val)
          (next-func val)
          error-symbol)))

  (define (symmetric predicate next-func expr-l expr-r error-symbol)
    (let ([val-l (eval-helper expr-l)]
          [val-r (eval-helper expr-r)])
      (if (and (predicate val-l)
               (predicate val-r))
          (next-func val-l val-r)
          error-symbol)))

  (define (asymmetric pred-l pred-r next-func expr-l expr-r error-symbol)
    (let ([val-l (eval-helper expr-l)]
          [val-r (eval-helper expr-r)])
      (if (and (pred-l val-l)
               (pred-r val-r))
          (next-func val-l val-r)
          error-symbol)))

  (define (eval-helper expr)
    (match expr
      ;; Boolean -> Boolean Expressions
      [(not* e) (unary boolean? eval-not e 'not-type-err)]
      [(and* l r) (symmetric boolean? eval-and l r 'and-type-err)]
      [(or* l r) (symmetric boolean? eval-or l r 'or-type-err)]
      [(eq* l r) (eval-helper (or* (and* l r) (and* (not* l) (not* r))))]
      ;; Nat x Nat -> Nat Expressions
      [(+* l r) (symmetric natural? eval-+ l r '+-type-err)]
      ;; Nat x Nat -> Boolean Expressions
      [(<* l r) (symmetric natural? eval-< l r '<-type-err)]
      [(=* l r) (symmetric natural? eval-= l r '=-type-err)]
      ;; Channel Expressions
      [(message* e) (unary boolean? eval-message e 'message-type-err)]
      ;; Buffer -> Boolean Predicates
      [(send-buf-empty?* b) (unary send-buf*? eval-send-buf-empty? b 'send-buf-empty-type-err)]
      [(recv-buf-full?* b) (unary recv-buf*? eval-recv-buf-full? b 'recv-buf-full-type-err)]
      ;; Buffer Expressions
      [(nat->send-buf* l v) (symmetric natural? eval-nat->send-buf l v 'nat->send-buf-type-err)]
      [(send-buf-get* b) (unary send-buf*? eval-send-buf-get b 'send-buf-get-type-err)]
      [(send-buf-next* b) (unary send-buf*? eval-send-buf-next b 'send-buf-next-type-err)]
      [(empty-recv-buf* l) (unary natural? eval-empty-recv-buf l 'empty-recv-buf-type-err)]
      [(recv-buf-put* b v) (asymmetric recv-buf*?
                                       boolean?
                                       eval-recv-buf-put b v
                                       'recv-buf-put-type-err)]
      [(recv-buf->nat* b) (unary recv-buf*? eval-recv-buf->nat b 'recv-buf->nat-type-err)]
      ;; Symbol |- *-Channel -> Boolean Predicates
      [(full?* id) (let ([typ (get-mapping id context)]
                        [val (get-mapping id state)])
                    (if (eq? typ 'recv-channel)
                        (channel*-valid val)
                        'full-type-err))]
      [(empty?* id) (let ([typ (get-mapping id context)]
                         [val (get-mapping id state)])
                     (if (eq? typ 'send-channel)
                         (not (channel*-valid val))
                         'empty-type-err))]
      ;; Symbol |- Recv-Channel -> Boolean Deconstructor
      [(value* id) (let ([typ (get-mapping id context)]
                         [val (get-mapping id state)])
                     (if (and (eq? typ 'recv-channel)
                              (channel*? val)
                              (channel*-valid val))
                         (channel*-value val)
                         'value-type-err))]
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
         [(symbol? expr)
          (let ([val (get-mapping expr state)])
            (cond
              [(type-check? term val) val]
              [(null? val) 'null-reference]
              [else 'term-type-err]))]
         [else 'expression-syntax-error])]))

  (eval-helper expression))

;; Interpret an assignment statement
;;
;; Apply the expression values to the corresponding variables, given a context
;; and start state. Expression values are with respect to the given start
;; state, not to any intermediate state.
;;
;; For conditional (case*) assignments, we apply the expression values if the
;; boolean expression guard is satisified. If no guards are satisified, then the
;; start state is returned.
(define (interpret-assign-stmts assignments context state)
  (struct assign-triple
    (vars exps condition)
    #:transparent)

  (define (apply-assignment l-var r-val next-func)
    (let* ([l-type (get-mapping l-var context)]
           [l-val (get-mapping l-var state)])
      (cond
        ;; propagate errors
        [(symbol? r-val) r-val]
        ;; bool := bool
        [(and (eq? l-type 'boolean)
              (boolean? r-val))
         next-func]
        ;; nat := nat
        [(and (eq? l-type 'natural)
              (natural? r-val))
         next-func]
        ;; (full) recv-channel := 'empty
        [(and (eq? l-type 'recv-channel)
              (channel*? l-val)
              (channel*-valid l-val)
              (channel*? r-val)
              (not (channel*-valid r-val)))
         next-func]
        ;; (empty) send-channel := message
        [(and (eq? l-type 'send-channel)
              (channel*? l-val)
              (not (channel*-valid l-val))
              (channel*? r-val)
              (channel*-valid r-val))
         next-func]
        ;; send-buf := send-buf
        [(and (eq? l-type 'send-buf)
              (send-buf*? r-val))
         next-func]
        ;; recv-buf := recv-buf
        [(and (eq? l-type 'recv-buf)
              (recv-buf*? r-val))
         next-func]
        ;; fall-through
        [else 'assignment-type-err])))

  (define (expand-cases vars cases)
    (map (lambda (c)
           (let ([exps (car c)]
                 [guard (cdr c)])
             (assign-triple vars exps guard)))
         cases))

  (define (regularize-assign assign)
    (match assign
      [(:=* vars exps)
       (match exps
         [(case* cases)
          (expand-cases vars cases)]
         [_ (assign-triple vars exps #t)])]))

  (define (filter-enabled-assigns to-check enabled-assigns)
    (match to-check
      ['() enabled-assigns]
      [(cons head tail)
       (match head
         [(assign-triple vars exps guard)
          (let ([guard-val (evaluate-expr guard context state)])
            (if (boolean? guard-val)
                (if guard-val
                    (filter-enabled-assigns tail (cons head enabled-assigns))
                    (filter-enabled-assigns tail enabled-assigns))
                'guard-type-err))])]))

  (define (vars-exps-to-commit assign-triples)
    (map cons
         (flatten (map assign-triple-vars assign-triples))
         (flatten (map assign-triple-exps assign-triples))))

  (define (commit var-exp next-state)
    (let* ([var (car var-exp)]
           [expr (cdr var-exp)]
           [val (evaluate-expr expr context state)])
      (apply-assignment var
                        val
                        (add-mapping var val next-state))))

  (let* ([regularized-assigns (flatten (map regularize-assign assignments))]
         [enabled-assigns (filter-enabled-assigns regularized-assigns '())])
    (cond
      ;; propagate error symbols
      [(symbol? enabled-assigns) enabled-assigns]
      ;; nothing enabled?
      [(null? enabled-assigns) state]
      ;; commit the enabled triples
      [else (let ([to-commit (vars-exps-to-commit enabled-assigns)])
              (foldl commit state to-commit))])))

;; Interpret the declaration clause. This just means taking adding the name to
;; type mapping and constructing a new environment. Takes an initial state.
(define (interpret-declare program state)
  (match program
    [(unity* declare _ _)
     (match declare
       [(declare* context)
        (environment* context state)])]))

(define (error-wrapper st f)
  (if (symbol? st)
      st
      (f st)))

;; Interpret the initially cause, given an existing environment with a context
;; and a state
(define (interpret-initially program env)
  (match program
    [(unity* _ initially _)
     (match initially
       [(initially* initial-assignment)
        (match env
          [(environment* cxt state)
           (error-wrapper
            (interpret-assign-stmts initial-assignment cxt state)
            (lambda (st)
              (environment* cxt st)))])])]))

;; Interpret the assign clause, given an existing environment with a context and
;; a state
(define (interpret-assign program env)
  (define (pick-stmts stmts)
    (list-ref stmts (random (length stmts))))

  (match program
    [(unity* _ _ assignments)
     (match assignments
       [(assign* assign-statements)
        (if (null? assign-statements)
            env
            (match env
              [(environment* cxt state)
               (error-wrapper
                (interpret-assign-stmts (pick-stmts assign-statements) cxt state)
                (lambda (st)
                  (environment* cxt st)))]))])]))

(provide context->external-vars
         context->internal-vars
         evaluate-expr
         interpret-declare
         interpret-initially
         interpret-assign)

;; Tests
(assert
 (let* ([initial-state (list (cons 'out (channel* #f null))
                             (cons 'in (channel* #t #t)))]
        [prog
         (unity*
          (declare*
           (list (cons 'reg 'natural)
                 (cons 'in-read 'boolean)
                 (cons 'in 'recv-channel)
                 (cons 'out 'send-channel)))
          (initially*
           (list
            (:=* (list 'reg
                       'in-read)
                 (list 42
                       #f))))
          (assign*
           (list
            ;; non-deterministic choice #1
            (list
             ;; parallel assignment #1a
             (:=* (list 'in-read
                        'out)
                  (case* (list (cons (list #t
                                           (message* (value* 'recv-channel)))
                                     (and* (not 'in-read)
                                           (and* (empty?* 'out)
                                                 (full?* 'in)))))))
             ;; parallel assignment #1b
             (:=* (list 'in-read
                        'in)
                  (case* (list (cons (list #f
                                           'empty)
                                     (and* 'in-read
                                           (full?* 'in)))))))
            ;; non-deterministic choice #2
            (list (:=* (list 'reg)
                       (list (+* 'reg 1)))))))]
        [env (interpret-declare prog initial-state)]
        [env2 (interpret-initially prog env)]
        [env3 (interpret-assign prog env2)])
   (and (environment*? env)
        (environment*? env2)
        (environment*? env3))))

;; Assert that send-buf and recv-buf conversions work
;; for all positive word sizes
(define-symbolic W N integer?)

(assert
 (unsat?
  (verify
   #:assume
   (assert
    (and (< 0 W)
         (<= 0 N)
         (< N (expt 2 W))))
   #:guarantee
   (assert
    (let* ([word-size W]
           [send-buffer (eval-nat->send-buf word-size N)]
           [send-word (send-buf*-vals send-buffer)]
           [recv-word (reverse send-word)]
           [recv-buffer (recv-buf* word-size recv-word)]
           [recv-nat (eval-recv-buf->nat recv-buffer)])
      (eq? N recv-nat))))))
