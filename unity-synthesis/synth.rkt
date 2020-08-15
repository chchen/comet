#lang rosette/safe

(require "util.rkt"
         "unity/concretize.rkt"
         "unity/environment.rkt"
         "unity/syntax.rkt"
         "unity/semantics.rkt"
         rosette/lib/match)

(define max-expression-depth 4)

;; The synthesis map provides data structures and mappings useful for synthesis:
;;
;; A list of UNITY external variables
;; A list of UNITY internal variables
;; A Verilog context implementing the UNITY context
;; A symbolic Verilog state from the Verilog context
;; A function: Verilog state -> UNITY state
;; A function: UNITY identifier -> Verilog state -> UNITY value
;; A function: UNITY identifier -> a list of Verilog identifiers
(struct synth-map
  (unity-external-vars
   unity-internal-vars
   target-context
   target-state
   target-id-writable?
   target-state->unity-state
   unity-id->target-state->unity-val
   unity-id->target-ids)
  #:transparent)

(struct synth-traces
  (initially
   assign)
  #:transparent)

(struct guarded-trace
  (guard
   trace)
  #:transparent)

(struct guarded-stmt
  (guard
   stmt)
  #:transparent)

(define (unity-prog->synth-traces unity-prog synthesis-map)
  (match unity-prog
    [(unity*
      (declare* unity-cxt)
      initially
      assign)
     (let* ([target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-start-st (synth-map-target-state synthesis-map)]
            [unity-start-st (target-st->unity-st target-start-st)]
            [unity-start-stobj (stobj unity-start-st)]
            [unity-start-env (interpret-declare unity-prog unity-start-stobj)]
            [unity-initialized-env (interpret-initially unity-prog unity-start-env)]
            [unity-assigned-env (interpret-assign unity-prog unity-start-env)])

       (define (symbolic-pair->guarded-trace p)
         (let* ([guard (car p)]
                [stobj (cdr p)]
                [state (stobj-state stobj)])
           (if (eq? state unity-start-st)
               '()
               (guarded-trace guard
                              (concretize-trace state guard)))))

       (define (stobj->guarded-traces stobj)
         (if (union? stobj)
             (flatten
              (map symbolic-pair->guarded-trace
                   (union-contents stobj)))
             (symbolic-pair->guarded-trace (cons #t stobj))))

       (begin
         (clear-asserts!)
         (synth-traces (stobj->guarded-traces
                        (environment*-stobj unity-initialized-env))
                       (stobj->guarded-traces
                        (environment*-stobj unity-assigned-env)))))]))

(define (unity-prog->assign-state unity-prog synthesis-map)
  (match unity-prog
    [(unity*
      (declare* unity-cxt)
      initially
      assign)
     (let* ([target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-start-st (synth-map-target-state synthesis-map)]
            [unity-start-st (target-st->unity-st target-start-st)]
            [unity-start-stobj (stobj unity-start-st)]
            [unity-start-env (interpret-declare unity-prog unity-start-stobj)]
            [unity-assigned-env (interpret-assign unity-prog unity-start-env)])
       (begin
         (clear-asserts!)
         (stobj-state
          (environment*-stobj unity-assigned-env))))]))

(define (unity-prog->initially-state unity-prog synthesis-map)
  (match unity-prog
    [(unity*
      (declare* unity-cxt)
      initially
      assign)
     (let* ([target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-start-st (synth-map-target-state synthesis-map)]
            [unity-start-st (target-st->unity-st target-start-st)]
            [unity-start-stobj (stobj unity-start-st)]
            [unity-start-env (interpret-declare unity-prog unity-start-stobj)]
            [unity-initialized-env (interpret-initially unity-prog unity-start-env)])
       (begin
         (clear-asserts!)
         (stobj-state
          (environment*-stobj unity-initialized-env))))]))

;; Ensures a monotonic transition for each key-value
;;
;; For each target pre and post state, we generate a inclusive list of
;; intermediate states, project them into UNITY states, and for every key, we
;; ensure that that key transitions from the unity-pre state into the unity-post
;; state and stays there.
(define (monotonic-keys-ok? keys target-pre target-post unity-pre unity-post target-st->unity-st)
  (andmap
   (lambda (key)
     (monotonic-ok? key target-pre target-post unity-pre unity-post target-st->unity-st))
   keys))

;; Ensures a monotonic transition for each key-value
;;
;; For each target pre and post state, we generate a inclusive list of
;; intermediate states, project them into UNITY states, and for every key, we
;; ensure that that key transitions from the unity-pre state into the unity-post
;; state and stays there.
(define (monotonic-ok? key target-pre target-post unity-pre unity-post target-st->unity-st)
  (let ([pre-val (get-mapping key unity-pre)]
        [post-val (get-mapping key unity-post)])

    (define (mark-value val)
      (cond
        [(eq? val pre-val) 'pre]
        [(eq? val post-val) 'post]
        [else 'fail]))

    (define (value-trace target-st)
      (let* ([mapped-state (target-st->unity-st target-st)]
             [mapped-value (get-mapping key mapped-state)])
        (cons (mark-value mapped-value)
              (if (eq? target-st target-pre)
                  '()
                  (value-trace (cdr target-st))))))

    (define (monotonic? phase last-phase)
      (if (or (eq? last-phase 'fail)
              (eq? phase 'fail)
              (and (eq? phase 'post)
                   (eq? last-phase 'pre)))
          'fail
          phase))

    (eq? (foldl monotonic? 'post (value-trace target-post))
         'pre)))

(define (symbolic-in-list? k l)
  (if (null? l)
      #f
      (let ([eqv (eq? k (car l))])
        (or (and (not (term? eqv))
                 eqv)
            (symbolic-in-list? k (cdr l))))))

;; Find the relevant target-vals to unity-val, Looking for target-vals that
;; share common symbolic variables with the unity-val
(define (relevant-values unity-val target-vals)
  (define (get-matches sym)
    (filter (lambda (v)
              (symbolic-in-list? sym (symbolics v)))
            target-vals))

  (flatten
   (map get-matches
        (symbolics unity-val))))

;; Find the relevant target-ids to unity-val, Looking for target-ids that map to
;; common symbolic variables with the unity-val
(define (relevant-ids unity-val target-state)
  (let* ([val-symbols (symbolics unity-val)])
    (map car
         (filter (lambda (mapping)
                   (symbolic-in-list? (cdr mapping) val-symbols))
                 target-state))))

;; For a list of guards evaluated in order, Rosette's symbolic unions include
;; additional clauses to ensure that each subequent clause contains the negation
;; of the disjunction of previous guards. This generates a parallel list of
;;
(define (guards->assumptions guards)
  (define (helper initial guards)
    (if (null? guards)
        '()
        (cons initial
              (helper (and (not (car guards))
                           initial)
                      (cdr guards)))))

  (helper #t guards))

(provide max-expression-depth
         synth-map
         synth-map-unity-external-vars
         synth-map-unity-internal-vars
         synth-map-target-context
         synth-map-target-state
         synth-map-target-id-writable?
         synth-map-target-state->unity-state
         synth-map-unity-id->target-state->unity-val
         synth-map-unity-id->target-ids
         synth-traces
         synth-traces-initially
         synth-traces-assign
         guarded-trace
         guarded-trace?
         guarded-trace-guard
         guarded-trace-trace
         guarded-stmt
         guarded-stmt?
         guarded-stmt-guard
         guarded-stmt-stmt
         unity-prog->synth-traces
         unity-prog->assign-state
         unity-prog->initially-state
         monotonic-keys-ok?
         monotonic-ok?
         relevant-values
         relevant-ids
         guards->assumptions)
