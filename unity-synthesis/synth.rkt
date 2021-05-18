#lang rosette/safe

(require "util.rkt"
         "unity/concretize.rkt"
         "unity/environment.rkt"
         "unity/syntax.rkt"
         "unity/semantics.rkt"
         rosette/lib/match)

(define max-expression-depth 4)

;; The synthesis map provides data structures and mappings useful for synthesis:
(struct synth-map
  (;; UNITY external variables
   unity-external-vars
   ;; UNITY internal variables
   unity-internal-vars
   ;; target type context
   target-context
   ;; target symbolic state
   target-state
   ;; is the target variable writable?
   ;; target ident -> boolean
   target-id-writable?
   ;; target state -> unity state
   target-state->unity-state
   ;; what is the unity variable's value in the mapped state
   ;; unity ident -> target-state -> unity value
   unity-id->target-state->unity-val
   ;; what target idents map to the unity variable
   ;; unity ident -> target idents
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
     (let* ([start-time (current-seconds)]
            [target-st->unity-st (synth-map-target-state->unity-state synthesis-map)]
            [target-start-st (synth-map-target-state synthesis-map)]
            [unity-start-st (target-st->unity-st target-start-st)]
            [unity-start-stobj (stobj unity-start-st)]
            [unity-start-env (interpret-declare unity-prog unity-start-stobj)]
            [unity-initialized-env (vc-wrapper (interpret-initially unity-prog unity-start-env))]
            [unity-assigned-env (vc-wrapper (interpret-assign unity-prog unity-start-env))])

       (define (symbolic-pair->guarded-trace p)
         (let* ([guard (car p)]
                [stobj (cdr p)]
                [state (stobj-state stobj)])
           (if (eq? state unity-start-st)
               (guarded-trace guard unity-start-st)
               (guarded-trace guard
                              state))))
                              ;; (concretize-trace state guard)))))

       (define (stobj->guarded-traces stobj)
         (if (union? stobj)
             (flatten
              (map symbolic-pair->guarded-trace
                   (union-contents stobj)))
             (symbolic-pair->guarded-trace (cons #t stobj))))

       (let ([init-guarded-traces (stobj->guarded-traces
                                   (environment*-stobj unity-initialized-env))]
             [assign-guarded-traces (stobj->guarded-traces
                                     (environment*-stobj unity-assigned-env))])
         (begin
           (display (format "[unity-prog->synth-traces] ~a sec.~n"
                            (- (current-seconds) start-time))
                    (current-error-port))
           (synth-traces init-guarded-traces
                         assign-guarded-traces))))]))

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
       (stobj-state
        (environment*-stobj unity-assigned-env)))]))

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
       (stobj-state
        (environment*-stobj unity-initialized-env)))]))

(define (unity-prog->assign-stobj unity-prog synthesis-map)
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
       (environment*-stobj unity-assigned-env))]))

(define (unity-prog->initially-stobj unity-prog synthesis-map)
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
       (environment*-stobj unity-initialized-env))]))

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

    ;; Generate a list of intermediate traces between trace and target-pre
    (define (intermediate-traces trace)
      (let ([mapped-trace (target-st->unity-st trace)])
        (if (eq? trace target-pre)
            (list mapped-trace)
            (cons mapped-trace
                  (intermediate-traces (cdr trace))))))

    ;; For a trace, find the value mapping for a key and compare it with the
    ;; target pre and post values. If they don't match, fail
    (define (mark-trace trace)
      (let ([trace-val (get-mapping key trace)])
        (cond
          [(eq? trace-val post-val) 'post]
          [(eq? trace-val pre-val) 'pre]
          [else 'fail])))

    (define (pre? mark)
      (eq? mark 'pre))

    (define (post? mark)
      (eq? mark 'post))

    (define (unknown? mark)
      (eq? mark 'unknown))

    (define (marks-ok? marks last-mark)
      (if (null? marks)
          (or (eq? last-mark 'pre)
              (eq? last-mark 'post))
          (match (car marks)
            ['pre (and (or (pre? last-mark)
                           (post? last-mark))
                       (marks-ok? (cdr marks) 'pre))]
            ['post (and (or (unknown? last-mark)
                            (post? last-mark))
                        (marks-ok? (cdr marks) 'post))]
            [_ #f])))

    (let* ([traces (intermediate-traces target-post)]
           [marks (map mark-trace traces)])
      (marks-ok? marks 'unknown))))


(define (symbolic-in-list? k l)
  (if (null? l)
      #f
      (or (concrete-eq? k (car l))
          (symbolic-in-list? k (cdr l)))))

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
;; of the disjunction of previous guards. When synthesizing an individual guard,
;; it would be nice to postulate the negation of the previous guards. This
;; generates a list of those postulates.
(define (guards->assumptions guards)
  (define (helper initial guards)
    (if (null? guards)
        '()
        (cons initial
              (helper (and (not (car guards))
                           initial)
                      (cdr guards)))))

  (helper #t guards))

;; How to check if a sequence of traces have valid data dependencies
;; For each trace:
;;
;; Extract the right hand side symbolics. If they are in the invalid list,
;; STOP. The ordering is invalid.
;;
;; If the right hand symbolics do not occur in the invalid list, take the left
;; hand side symbolics, compute the closure with the invalidation sets, and add
;; them to the invalid list, and recurse.
(define (traces-dep-check-fn synth-map)
  (let* ([target-st (synth-map-target-state synth-map)]
         [unity-id->target-ids (synth-map-unity-id->target-ids synth-map)]
         [unity-ids (append (synth-map-unity-external-vars synth-map)
                            (synth-map-unity-internal-vars synth-map))])

    ;; Generate mappings id-symbol |-> symbols that relate to the same unity-id
    (define (unity-id->invalidation-mappings unity-id)
      (let* ([target-ids (unity-id->target-ids unity-id)]
             [target-symbolics (map (lambda (k) (get-mapping k target-st))
                                    target-ids)])
        (map (lambda (t-id)
               (cons t-id target-symbolics))
             target-ids)))

    (let ([invalidation-map
           (apply append (map unity-id->invalidation-mappings unity-ids))])

      (define (check-traces traces invalid)
        (if (null? traces)
            #t
            (let* ([trace (car traces)]
                   [lhs-identifiers (map car trace)]
                   [newly-invalid (flatten
                                   (map (lambda (key)
                                          (get-mapping key invalidation-map))
                                        lhs-identifiers))]
                   [dependencies (apply append (map symbolics
                                                    (map cdr trace)))]
                   [tail (cdr traces)])
              (and (not (ormap (lambda (s)
                                 (in-symbolic-list? s invalid))
                               dependencies))
                   (check-traces tail
                                 (append newly-invalid invalid))))))

      (lambda (traces)
        (check-traces traces '())))))

(define decomposable-ops
  (append (list !)
          (list bvnot)
          (list &&
                ||
                <=>)
          (list bvadd
                bvand
                bveq
                bvlshr
                bvor
                bvshl
                bvult
                bvxor)))

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
         synth-traces?
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
         unity-prog->assign-stobj
         unity-prog->initially-stobj
         monotonic-keys-ok?
         monotonic-ok?
         symbolic-in-list?
         relevant-values
         relevant-ids
         guards->assumptions
         traces-dep-check-fn
         decomposable-ops)
