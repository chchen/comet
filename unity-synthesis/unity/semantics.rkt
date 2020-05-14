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

  (send-buf* 0
             (nat->bool-list val (sub1 len))))

(define (eval-send-buf-get buf)
  (define (walk-list dist lst)
    (if (<= dist 0)
        (car lst)
        (walk-list (sub1 dist) (cdr lst))))

  (walk-list send-buf*-sent
             send-buf*-vals))

(define (eval-send-buf-next buf)
  (send-buf* (add1 send-buf*-sent)
             send-buf*-vals))

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
     (recv-buf* (add1 rcvd) (insert-list rcvd item vals))]))

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

  (bool-list->nat recv-buf*-vals 0))

;; Evaluate an expression. Takes an expression, context, and a state
(define (evaluate-expr expression context state-object)
  (match state-object
    [(stobj state)
     (define (type-check? id val)
       (case (get-mapping id context)
         ['boolean (boolean? val)]
         ['natural (natural? val)]
         ['recv-channel (channel*? val)]
         ['send-channel (channel*? val)]
         ['recv-buf (recv-buf*? val)]
         ['send-buf (send-buf*? val)]
         [else #f]))

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
         [(send-buf-get* b) (unary eval-send-buf-get b)]
         [(send-buf-next* b) (unary eval-send-buf-next b)]
         [(empty-recv-buf* l) (unary eval-empty-recv-buf l)]
         [(recv-buf-put* b v) (binary eval-recv-buf-put b v)]
         [(recv-buf->nat* b) (unary eval-recv-buf->nat b)]
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
         ['() '()]
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
;; for all positive word sizes

(define-symbolic W N integer?)
(define-symbolic X Y boolean?)

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
