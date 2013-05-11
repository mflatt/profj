(module analysis scheme/base
  
  (require "ast.ss"
           "types.ss"
           scheme/class)
  
  (define self (make-parameter #f))
  (define types (make-parameter #f))
  
  ;(make-field-status id owner mod (list id) boolean)
  (define-struct field-status (id owner mod? alias trans?))
  
  ;owner = 'self | shared | type 
  ;(make-shared (listof owner))
  (define-struct shared (users))
  ;mod = #t | #f | 'deep | 'bottom
  
  ;field-control: [listof id] method type type-records -> [listof field-status]
  (define (field-control fields method self-type type-recs)
    (parameterize ([self self-type]
                   [types type-recs])
      (field-control-stmt (map init-field-status fields) (method-body method))))
  
  ;init-field-status: id -> field-status
  (define (init-field-status field) (make-field-status field 'self #f null #f))
  
  ;field-control-stmt: (listof field-status) statement -> (listof field-status)
  (define (field-control-stmt fields stmt)
    (cond
      [(ifS? stmt)
       (let ([fields (field-control-stmt (field-control-exp fields (ifS-cond stmt))
                                         (ifS-then stmt))])
         (if (ifS-else stmt)
             (field-control-stmt fields (ifS-else stmt))
             fields))]
      [(throw? stmt)
       (field-control-exp fields (throw-expr stmt))]
      [(return? stmt)
       (if (return-expr stmt)
           (field-control-exp fields (return-expr stmt))
           fields)]
      [(while? stmt)
       (field-control-stmt (field-control-exp fields (while-cond stmt))
                           (while-loop stmt))]
      [(doS? stmt)
       (field-control-stmt (field-control-exp fields (doS-cond stmt)) (doS-loop stmt))]
      [(for? stmt)
       (let* ([inits (field-control-for-inits fields (for-init stmt))]
              [cond (field-control-exp inits (for-cond stmt))]
              [incr (foldl (lambda (e fields) (field-control-exp fields e)) cond (for-incr stmt))])
         (field-control-stmt incr (for-loop stmt)))]
      [(try? stmt)
       (let* ([body (field-control-stmt fields (try-body stmt))]
              [catches (field-control-catch body (try-catches stmt))])
         (if (try-finally stmt)
             (field-control-stmt catches (try-finally stmt))
             catches))]
      [(block? stmt)
       (foldl (lambda (s fields) (field-control-stmt fields s)) fields (block-stmts stmt))]
      [(field? stmt) (add-field stmt fields)]
      [(def? stmt) fields]
      [(break? stmt) fields]
      [(continue? stmt) fields]
      [(label? stmt)
       (field-control-stmt fields (label-stmt stmt))]
      [(synchronized? stmt)
       (field-control-stmt (field-control-exp fields (synchronized-expr stmt))
                           (synchronized-stmt stmt))]
      [(statement-expression? stmt) (field-control-exp fields stmt)]
      [else
       (error 'field-control-stmt (format "field-control-stmt given unsupported: ~s" stmt))]))
  
  (define (field-control-for-inits fields inits) 
    (cond
      [(null? inits) fields]
      [(statement-expression? (car inits)) (foldl (lambda (e fields) (field-control-exp fields e)) fields inits)]
      [else (foldl (lambda (i fields) (add-field i fields)) fields inits)]))
  (define (field-control-catch fields catches) fields)
  (define (add-field var fields)
    (cond
      [(var-decl? var) (cons (make-field-status (var-decl-name var) 'self #f null #t) fields)]
      [(var-init? var) 
       (update-control (cons (make-field-status (var-decl-name (var-init-var-decl var)) 'self #f null #t) fields)
                       (var-decl-name (var-init-var-decl var))
                       (var-init-init var))]
      [else fields]))
  
  ;field-control-exp: (listof field-status) expression -> (listof field-status)
  (define (field-control-exp fields expr)
    (cond
      [(literal? expr) fields]
      [(bin-op? expr) 
       (field-control-exp (field-control-exp fields (bin-op-left expr)) (bin-op-right expr))]
      [(access? expr) 
       (cond
         [(local-access? (access-name expr)) fields]
         [else 
          (field-control-exp fields (field-access-object (access-name expr)))])]
      [(or (special-name? expr) (specified-this? expr)) fields]
      [(call? expr) 
       (assess-control (field-control-exp fields (call-expr expr))
                       (expr-types (call-expr expr))
                       (call-args expr))]
      [(class-alloc? expr) 
       (assess-control fields
                       (expr-types expr)
                       (class-alloc-args expr))]
      [(inner-alloc? expr) 
       (assess-control (field-control-exp fields (inner-alloc-obj expr))
                       (expr-types expr)
                       (inner-alloc-args expr))]
      [(array-alloc? expr)
       (foldl (lambda (e fields) (field-control-exp fields e)) fields (array-alloc-size expr))]
      [(array-alloc-init? expr) #;incomplete fields]
      [(cond-expression? expr) 
       (field-control-exp
        (field-control-exp (field-control-exp fields (cond-expression-cond expr))
                           (cond-expression-then expr))
        (cond-expression-else expr))]
      [(array-access? expr) 
       (field-control-exp (field-control-exp fields (array-access-name expr))
                          (array-access-index expr))]
      [(post-expr? expr) 
       (update-control (field-control-exp fields (post-expr-expr expr))
                       (post-expr-expr expr)
                       (post-expr-expr expr))]
      [(pre-expr? expr) 
       (update-control (field-control-exp fields (pre-expr-expr expr))
                       (pre-expr-expr expr)
                       (pre-expr-expr expr))]
      [(unary? expr) (field-control-exp fields (unary-expr expr))]
      [(cast? expr) (field-control-exp fields (cast-expr expr))]
      [(instanceof? expr) (field-control-exp fields (instanceof-expr expr))]
      [(assignment? expr) 
       (update-control (field-control-exp (field-control-exp fields (assignment-left expr)) (assignment-right expr))
                       (assignment-right expr)
                       (assignment-left expr))]
      ((check? expr) fields)
      ((test-id? expr) fields)
      (else
       (error 'field-control-exp fields (format "field-control-exp given unrecognized expression ~s" expr)))))
  
  ;field=? (id -> (expr -> boolean))
  (define (field=? id)
    (lambda (arg)
      (or
       (and (access? arg) (local-access? (access-name arg))
            (equal? (id-string id) (id-string (local-access-name (access-name arg)))))
       (and (access? arg) (field-access? (access-name arg)) 
            (equal? (id-string id) (id-string (field-access-field (access-name arg)))))
       (and (array-access? arg) ((field=? id) (array-access-name arg))))))
  
  ;assess-control: (listof field-status) expr (listof expr) -> (listof field-status)
  (define (assess-control fields passed-to args)
    (letrec ([field-arg?
              (lambda (arg)
                (or (and (access? arg) (local-access? (access-name arg)))
                    (and (access? arg) (field-access? (access-name arg))
                         (type=? (self) (expr-types (field-access-object (access-name arg))) (types)))
                    (and (array-access? arg) (access? (array-access-name arg)) (field-arg? (array-access-name arg)))))]
             [passed-fields (filter field-arg? args)]
             [up-fields (foldl (lambda (e fields) (field-control-exp fields e)) fields args)])
      (cond
        [(null? passed-fields) up-fields]
        [else
         (map (lambda (field)
                (let ([field-arg (findf (field=? (field-status-id field)) passed-fields)])
                  (cond
                    [(not field-arg) field]
                    [(type=? (self) passed-to (types)) 
                     (make-field-status (field-status-id field) 
                                        (merge-ownership (field-status-owner field) 'self)
                                        'bottom
                                        (field-status-alias field)
                                        (field-status-trans? field))]
                    [else
                     (make-field-status (field-status-id field)
                                        (merge-ownership (field-status-owner field) passed-to)
                                        (field-status-mod? field)
                                        (field-status-alias field)
                                        (field-status-trans? field))])))
              up-fields)])))
  
  ;merge-ownership: owner owner -> owner
  (define (merge-ownership previous add) 
    (cond
      [(and (eq? previous 'self) (eq? add 'self)) 'self]
      [(eq? previous 'self) (list 'self add)]
      [(eq? add 'self) previous]
      [(and (not (pair? previous)) (type=? previous add (types))) previous]
      [(not (pair? previous)) (list previous add)]
      [else (cons add previous)]))
  
  ;update-control: (listof field-status) expression expression -> (listof field-status)
  (define (update-control fields assignee expr)
    (map (lambda (f)
           (cond
             [(field=? (field-status-id f) assignee) 
              (make-field-status (field-status-id f)
                                 (field-status-owner f)
                                 #t
                                 (update-aliases (field-status-alias f) expr)
                                 (field-status-trans? f))]
             [else f]))
         fields))

  ;update-aliases: (list of id) expr -> (list of id)
  (define (update-aliases aliases expr)
    (cond 
      [(and (access? expr) (local-access? (access-name expr)))
       (cons (local-access-name (access-name expr)) aliases)]
      [(and (access? expr) (field-access? (access-name expr)) (type=? (self) (field-access-object (access-name expr)) (types)))
       (cons (field-access-field (access-name expr)) aliases)]
      [else aliases]))  
  
  )