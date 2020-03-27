#lang rosette

(require "../util.rkt"
         "environment.rkt"
         "syntax.rkt"
         rosette/lib/match)

(define (natural? n)
  (exact-nonnegative-integer? n))

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

(define (channel-empty? val)
  (and (channel*? val)
       (not (channel*-valid val))))

(define (channel-full? val)
  (and (channel*? val)
       (channel*-valid val)))

(define (eval-message val)
  (channel* #t val))

(define (eval-value val)
  (channel*-value val))

(define (eval-send-empty? buf)
  (eq? 0 (length (send-buf*-val buf))))

(define (eval-recv-full? buf)
  (eq? (recv-buf*-len buf)
       (length (recv-buf*-val buf))))

(define (eval-nat->send-buf len val)
  (define (nat->bool-list v pow)
    (if (< pow 0) ;; base case
        '()
        (let ([e (expt 2 pow)])
          (if (>= v e)
              (cons #t (nat->bool-list (- v e)
                                       (- pow 1)))
              (cons #f (nat->bool-list v
                                       (- pow 1)))))))

  (let ([maxval (- (expt 2 len) 1)])
    (if (> val maxval)
        'send-buf-overflow
        (send-buf* len (nat->bool-list val (- len 1))))))

(define (eval-send-buf-head buf)
  (match buf
    [(send-buf* len val)
     (if (null? val)
         'send-buf-no-head
         (car val))]))

(define (eval-send-buf-tail buf)
  (match buf
    [(send-buf* len val)
     (if (null? val)
         'send-buf-no-tail
         (send-buf* len (cdr val)))]))

(define (eval-empty-recv-buf len)
  (recv-buf* len '()))

(define (eval-recv-buf-insert buf item)
  (match buf
    [(recv-buf* len val)
     (if (>= (length val) len)
         'recv-buf-full
         (recv-buf* len (cons item val)))]))

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
    [(recv-buf* len val)
     (if (not (= len (length val)))
         'recv-buf-not-full
         (bool-list->nat val 0))]))

;; Evaluate an expression. Takes an expression, context, and a state
(define (evaluate-expr expression context state)
  (define (type-check? id val)
    (match (cxt-lookup id context)
      ['boolean (boolean? val)]
      ['natural (natural? val)]
      ['channel (channel*? val)]
      ['send-buf (send-buf*? val)]
      ['recv-buf (recv-buf*? val)]
      [_ #f]))

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
      ;; Channel -> Boolean Expressions
      [(full?* c) (unary channel*? channel*-valid c 'full-type-err)]
      [(empty?* c) (eval-helper (not* (full?* c)))]
      ;; Channel Expressions
      [(message* e) (unary boolean? eval-message e 'message-type-err)]
      [(value* c) (unary channel-full? channel*-value c 'value-type-err)]
      ;; Buffer -> Boolean Expressions
      [(send-empty?* b) (unary send-buf*? eval-send-empty? b 'send-empty-type-err)]
      [(recv-full?* b) (unary recv-buf*? eval-recv-full? b 'recv-full-type-err)]
      ;; Buffer Expressions
      [(nat->send-buf* s v) (symmetric natural? eval-nat->send-buf s v 'nat->send-buf-type-err)]
      [(send-buf-head* b) (unary send-buf*? eval-send-buf-head b 'send-buf-head-type-err)]
      [(send-buf-tail* b) (unary send-buf*? eval-send-buf-tail b 'send-buf-tail-type-err)]
      [(empty-recv-buf* s) (unary natural? eval-empty-recv-buf s 'empty-recv-buf-type-err)]
      [(recv-buf-insert* b v) (asymmetric recv-buf*?
                                          boolean?
                                          eval-recv-buf-insert b v
                                          'recv-buf-insert-type-err)]
      [(recv-buf->nat* b) (unary recv-buf*? eval-recv-buf->nat b 'recv-buf->nat-type-err)]
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
          (let ([val (state-get expr state)])
            (cond
              [(type-check? term val) val]
              [(null? val) 'null-reference]
              [else 'term-type-err]))]
         [else 'syntax-error])]))

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
(define (interpret-assign-stmt assignment context state)
  (define (apply-assignment l-var r-val next-func)
    (let* ([l-type (cxt-lookup l-var context)]
           [l-val (state-get l-var state)])
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
        ;; (undefined) channel := channel
        [(and (eq? l-type 'channel)
              (null? l-val)
              (channel*? r-val))
         next-func]
        ;; (full) channel := 'empty
        [(and (eq? l-type 'channel)
              (channel-full? l-val)
              (channel*? r-val)
              (not (channel*-valid r-val)))
         next-func]
        ;; (empty) channel := message
        [(and (eq? l-type 'channel)
              (channel-empty? l-val)
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

  (define (filter-expressions exps-guards)
    (match exps-guards
      [(cons (cons exps guard) tail)
       (let ([guard-val (evaluate-expr guard context state)])
         (if (boolean? guard-val)
             (if guard-val exps (filter-expressions tail))
             'guard-type-err))]
      [_ '()]))

  (define (commit vars exps next-state)
    (if (and (pair? vars)
             (pair? exps))
        (let* ([var (car vars)]
               [expr (car exps)]
               [val (evaluate-expr expr context state)]
               [v-tail (cdr vars)]
               [e-tail (cdr exps)])
          (apply-assignment var
                            val
                            (commit v-tail
                                    e-tail
                                    (state-put var val next-state))))
          next-state))

    (match assignment
      [(:=* vars (case* exps-guards))
       (let ([exps (filter-expressions exps-guards)])
         (cond
           ;; propagate errors
           [(symbol? exps) exps]
           ;; no guards satisfied
           [(null? exps) state]
           [else (commit vars exps state)]))]
      [(:=* vars exps) (commit vars exps state)]))

;; Interpret the declaration clause. This just means taking adding the name to
;; type mapping and constructing a new environment
(define (interpret-declare program)
  (match program
    [(unity* (declare* type-declarations) _ _)
     (environment* type-declarations '())]))

(define (error-wrapper st f)
  (if (symbol? st)
      st
      (f st)))

;; Interpret the initially cause, given an existing environment with a context
;; and a state
(define (interpret-initially program env)
  (match program
    [(unity* _ (initially* initial-assignment) _)
     (match env
       [(environment* cxt state)
        (error-wrapper
         (interpret-assign-stmt initial-assignment cxt state)
         (lambda (st)
           (environment* cxt st)))])]))

;; Interpret the assign clause, given an existing environment with a context and
;; a state
(define (interpret-assign program env)
  (define (pick-stmt stmts)
    (list-ref stmts (random (length stmts))))

  (match program
    [(unity* _ _ (assign* '())) env]
    [(unity* _ _ (assign* assign-statements))
     (match env
       [(environment* cxt state)
        (error-wrapper
         (interpret-assign-stmt (pick-stmt assign-statements) cxt state)
         (lambda (st)
           (environment* cxt st)))])]))

(provide evaluate-expr
         interpret-assign-stmt
         interpret-declare
         interpret-initially
         interpret-assign)

;; Test

(assert
 (let* ([prog
         (unity*
          (declare* (list (cons 'reg 'boolean)
                          (cons 'sbuf 'send-buf)
                          (cons 'out 'channel)
                          (cons 'rbuf 'recv-buf)
                          (cons 'in 'channel)
                          (cons 'counter 'natural)))
          (initially* (:=* (list 'reg
                                 'sbuf
                                 'out
                                 'rbuf
                                 'in
                                 'counter)
                           (list #f
                                 (nat->send-buf* 8 128)
                                 'empty
                                 (empty-recv-buf* 8)
                                 (message* #t)
                                 0)))
          (assign* (list (:=* (list 'reg
                                    'sbuf
                                    'out
                                    'rbuf
                                    'in
                                    'counter)
                              (case* (list (cons (list (not* 'reg)
                                                       (send-buf-tail* 'sbuf)
                                                       (message* (send-buf-head* 'sbuf))
                                                       (recv-buf-insert* 'rbuf (value* 'in))
                                                       'empty
                                                       (+* 'counter 1))
                                                 (and*
                                                  (empty?* 'out)
                                                  (and*
                                                   (not* (send-empty?* 'sbuf))
                                                   (and*
                                                    (full?* 'in)
                                                    (not* (recv-full?* 'rbuf))))))))))))]
        [env (interpret-declare prog)]
        [env2 (interpret-initially prog env)]
        [env3 (interpret-assign prog env2)])
   (and (environment*? env)
        (environment*? env2)
        (environment*? env3))))

;; Assert that send-buf and recv-buf conversions work
;; for all positive word sizes
(define-symbolic W N integer?)
(assert
 (eq? (unsat)
      (verify
       #:assume (assert (and (< 0 W)
                             (<= 0 N)
                             (< N (expt 2 W))))
       #:guarantee (assert
                    (let* ([word-size W]
                           [send-buffer (eval-nat->send-buf word-size N)]
                           [send-word (send-buf*-val send-buffer)]
                           [recv-word (reverse send-word)]
                           [recv-buffer (recv-buf* word-size recv-word)]
                           [recv-nat (eval-recv-buf->nat recv-buffer)])
                      (eq? N recv-nat))))))
