(module types racket/base

  (require 
   (only-in srfi/1 lset-intersection)
   racket/pretty
   racket/list
   racket/bool
   racket/class
   "ast.rkt")
  (require racket/pretty)

  (provide (except-out (all-defined-out)
                       number-assign-conversions remove-dups meth-member?
                       contained-in? consolidate-lists subset? depth conversion-steps
                       generate-require-spec))

  (define (with-location location type-recs fn)
    (let ((old-location (send type-recs get-location)))
      (send type-recs set-location2! location)
      (begin0
        (fn)
        (send type-recs set-location2! old-location))))

  (define-syntax-rule
    (setting-location (type-recs location) body ...)
    (with-location location type-recs (lambda () body ...)))
  
  ;; symbol-type = 'null | 'string | 'boolean | 'char | 'byte | 'short | 'int
  ;;             | 'long | 'float | 'double | 'void | 'dynamic
  ;; reference-type = 'null | 'string | (make-ref-type string (list string))
  ;; array-type = (make-array-type type int)
  ;; type = symbol-type
  ;;      | reference-type
  ;;      | array-type
  ;;      | dynamic-val
  ;;      | unknown-ref

  (define-struct ref-type (class/iface path) #:transparent)
  (define-struct array-type (type dim))
  
  (define object-type (make-ref-type "Object" `("java" "lang")))
  (define string-type (make-ref-type "String" `("java" "lang")))
  (define throw-type (make-ref-type "Throwable" `("java" "lang")))
  (define runtime-exn-type (make-ref-type "RuntimeException" `("java" "lang")))
  (define serializable-type (make-ref-type "Serializable" `("java" "io")))
  (define comparable-type (make-ref-type "Comparable" `("java" "lang")))
  (define cloneable-type (make-ref-type "Cloneable" `("java" "lang")))
  
  (define (object-method? m-rec)
    (or 
     (and (equal? (method-record-name m-rec) "equals")
          (eq? (method-record-rtype m-rec) 'boolean)
          (= 1 (length (method-record-atypes m-rec)))
          (type=? object-type (car (method-record-atypes m-rec))))
     (and (equal? (method-record-name m-rec) "hashcode")
          (eq? (method-record-rtype m-rec) 'int)
          (= 0 (length (method-record-atypes m-rec))))
     ))
  
;                                                                                                          
;                                                                                                          
;                                                   ;                       ;         ;                    
;                                                   ;                       ;                              
;  ;;;;;;;                                          ;                       ;                              
;     ;                                             ;                       ;                              
;     ;     ;    ;  ; ;;;    ;;;;             ;;;   ; ;;;    ;;;;     ;;;   ;   ;   ;;;     ; ;;;    ;;; ; 
;     ;      ;   ;  ;;  ;;   ;  ;;           ;   ;  ;;   ;   ;  ;;   ;   ;  ;  ;      ;     ;;   ;  ;;  ;; 
;     ;      ;  ;   ;    ;  ;    ;          ;       ;    ;  ;    ;  ;       ; ;       ;     ;    ;  ;    ; 
;     ;      ;  ;   ;    ;  ;;;;;;          ;       ;    ;  ;;;;;;  ;       ;;;       ;     ;    ;  ;    ; 
;     ;       ; ;   ;    ;  ;               ;       ;    ;  ;       ;       ;  ;      ;     ;    ;  ;    ; 
;     ;       ;;    ;;  ;;   ;   ;           ;   ;  ;    ;   ;   ;   ;   ;  ;   ;     ;     ;    ;  ;;  ;; 
;     ;        ;    ; ;;;     ;;;             ;;;   ;    ;    ;;;     ;;;   ;    ;  ;;;;;   ;    ;   ;;; ; 
;              ;    ;                                                                                    ; 
;             ;     ;                                                                                ;  ;; 
;            ;;     ;                                                                                 ;;;  
;                                                                                                          

  
  ;; reference-type: 'a -> boolean
  (define (reference-type? x)
    (if (and (dynamic-val? x) (dynamic-val-type x))
        (reference-type? (dynamic-val-type x))
        (or (dynamic-val? x) 
            (unknown-ref? x)
            (ref-type? x) 
            (memq x `(null string)))))
  
  ;;reference-or-array-type: 'a -> boolean
  (define (reference-or-array-type? x)
    (or (reference-type? x)
        (array-type? x)))

  ;;is-string?: 'a -> boolean
  (define (is-string-type? s)
    (if (dynamic-val? s)
        (is-string-type? (dynamic-val-type s))
        (and (reference-type? s)
             (or (eq? 'string s) (type=? s string-type)))))
  
  ;; 4.2
  ;; prim-integral-type?: 'a -> boolean
  (define (prim-integral-type? t)
    (cond
      ((and (dynamic-val? t) (dynamic-val-type t)) 
       (prim-integral-type? (dynamic-val-type t)))
      ((dynamic-val? t) #t)
      (else (memq t `(byte short int long char)))))
  ;; prim-numeric-type?: 'a -> boolean
  (define (prim-numeric-type? t)
    (cond 
      ((and (dynamic-val? t) (dynamic-val-type t))
       (prim-numeric-type? (dynamic-val-type t)))
      ((dynamic-val? t) #t)
      (else (or (prim-integral-type? t) (memq t `(float double))))))
  
  ;; type=?: type type -> boolean
  (define (type=? t1 t2)
    (cond
      ((and (symbol? t1) (symbol? t2))
       (symbol=? t1 t2))
      ((and (ref-type? t1) (ref-type? t2))
       (and (string=? (ref-type-class/iface t1) (ref-type-class/iface t2))
            (= (length (ref-type-path t1)) (length (ref-type-path t2)))
            (andmap string=?
                    (ref-type-path t1)
                    (ref-type-path t2))))
      ((and (array-type? t1) (array-type? t2))
       (and (= (array-type-dim t1) (array-type-dim t2))
            (type=? (array-type-type t1) (array-type-type t2))))
      ((or (symbol? t1) (symbol? t2))
       (or (or (and (eq? t1 'null) (ref-type? t2))
               (and (eq? t2 'null) (ref-type? t1)))
           (and (eq? t1 'string) (type=? t2 string-type))
           (and (eq? t2 'string) (type=? t1 string-type))))
      (else #f)))
  
  ;; 5.1.2
  ;; widening-prim-conversion: symbol-type symbol-type -> boolean
  (define (widening-prim-conversion to from)
    (cond
      ((symbol=? to from) #t)
      ((symbol=? to 'char)
       (memq from `(byte short int))) ;;AML This is not widening, but is accepted (kind of, I'm not checking the value)
      ((symbol=? 'short to)
       (symbol=? 'byte from))
      ((symbol=? 'int to)
       (memq from `(byte short char)))
      ((symbol=? 'long to)
       (memq from `(byte short char int)))
      ((symbol=? 'float to)
       (memq from `(byte short char int long)))
      ((symbol=? 'double to)
       (memq from `(byte short char int long float)))))
  
  ;; 5.1.4
  ;; widening-ref-conversion: type type type-records -> boolean
  (define (widening-ref-conversion to from type-recs)
    (cond
      ((and (symbol? from) (symbol=? from 'null))
       (or (ref-type? to) (eq? 'string to) (array-type? to)))
      ((and (symbol? from) (symbol=? from 'string))
       (or (type=? to object-type) 
           (type=? to serializable-type) 
           (type=? to comparable-type)))
      ((and (ref-type? from) (ref-type? to))
       (or (is-subclass? from to type-recs)
           (implements? from to type-recs)
           (and (is-interface? from type-recs)
                (type=? object-type to))))
      ((array-type? from)
       (or (type=? object-type to)
           (type=? cloneable-type to)
           (type=? serializable-type to)
           (and (array-type? to) (= (array-type-dim from) (array-type-dim to))
                (assignment-conversion (array-type-type to) (array-type-type from) type-recs))))
      (else #f)))
  
  ;; 5.2
  ;; SKIP - possible narrowing conversion for constants
  ;; assignment-conversion: type type type-records -> boolean
  (define (assignment-conversion to from type-recs)
    (cond
      ((dynamic-val? to)
       (cond
         ((dynamic-val-type to) => (lambda (t) (assignment-conversion t from type-recs)))
         (else (set-dynamic-val-type! to from) #t)))
      ((dynamic-val? from)
       (cond
         ((dynamic-val-type from) => (lambda (t) (assignment-conversion to t type-recs)))
         (else (set-dynamic-val-type! from to) #t)))
      ((eq? to 'dynamic) #t)
      ((type=? to from) #t)
      ((and (prim-numeric-type? to) (prim-numeric-type? from))
       (widening-prim-conversion to from))
      (else
       (widening-ref-conversion to from type-recs))))
  
  ;castable?: reference-type reference-type type-records -> boolean
  (define (castable? from to type-recs)
    (or (dynamic-val? from)
        (dynamic-val? to)
        (eq? 'dynamic to)
        (eq? 'null from)
        (eq? 'null to)
        (let ((from-record (and (not (array-type? from)) (send type-recs get-class-record from)))
              (to-record (and (not (array-type? to))
                              (get-record (send type-recs get-class-record to) type-recs))))
          (cond
            ((and to-record from-record
                  (class-record-class? from-record)
                  (class-record-class? to-record))
             (or (is-eq-subclass? from to type-recs)
                 (is-eq-subclass? to from type-recs)))
            ((and to-record from-record (class-record-class? from-record))
             (or (not (memq 'final (class-record-modifiers from-record)))
                 (implements? from to type-recs)))
            ((and (not to-record) from-record (class-record-class? from-record))
             (type=? object-type from))
            ((and to-record from-record (class-record-class? to-record))
             (or (not (memq 'final (class-record-modifiers to-record)))
                 (implements? to from type-recs)))
            ((and to-record from-record (not (class-record-class? to-record)))
             (not (signature-conflicts? (class-record-methods to-record)
                                        (class-record-methods from-record))))
            ((and (not from-record) to-record (class-record-class? to-record))
             (type=? object-type to))
            ((and (not from-record) to-record)
             (or (type=? serializable-type to)
                 (type=? cloneable-type to)))
            (else
             (or (type=? (array-type-type to) (array-type-type from))
                 (castable? (array-type-type from)
                            (array-type-type to)
                            type-recs)))))))
  
  ;Do the two lists of method signatures have conflicting methods
  ;signature-conflicts? (list method-record) (list method-record) -> bool
  (define (signature-conflicts? methods1 methods2)
    (let ((same-sigs (lset-intersection signature-equals? methods1 methods2))
          (same-rets (lset-intersection full-signature-equals? methods1 methods2)))
      (not (= (length same-sigs) (length same-rets)))))

  ;Do the two methods have same name and argument types
  ;signature-equals? method-record method-record -> bool
  (define (signature-equals? m1 m2)
    (and (equal? (method-record-name m1)
                 (method-record-name m2))
         (= (length (method-record-atypes m1))
            (length (method-record-atypes m2)))
         (andmap type=? (method-record-atypes m1) (method-record-atypes m2))))
  ;Do the two methods have the same name, arguments and return types
  ;full-signagure-equals? method-record method-record -> bool
  (define (full-signature-equals? m1 m2)
    (and (signature-equals? m1 m2)
         (type=? (method-record-rtype m1) (method-record-rtype m2))))
    
  ;;equal-greater-access? (list symbol) (list symbol) -> boolean
  (define (equal-greater-access? mods-l mods-r)
    (let ([eq-gt? 
           (lambda (acc-l acc-r)
             (case acc-l
               [(public) (memq acc-r '(package protected public))]
               [(protected) (memq acc-r '(package protected))]
               [(package) (memq acc-r '(package))]
               [else #f]))])
      (eq-gt? (extract-access mods-l) (extract-access mods-r))))
  
  (define (extract-access mods)
    (cond
      [(memq 'public mods) 'public]
      [(memq 'protected mods) 'protected]
      [(memq 'private mods) 'private]
      [else 'package]))          
  
  ;; type-spec-to-type: type-spec (U #f (list string) symbol type-records -> type
  (define (type-spec-to-type ts container-class level type-recs)
    (let* ((ts-name (type-spec-name ts))
           (t (cond
                ((memq ts-name `(null string boolean char byte short int long float double void ctor dynamic)) ts-name)
                ((name? ts-name) (name->type ts-name container-class (type-spec-src ts) level type-recs)))))
      (if (> (type-spec-dim ts) 0)
          (make-array-type t (type-spec-dim ts))
          t)))

  ;name->type: name (U (list string) #f) src symbol type-records -> type
  (define (name->type n container-class src level type-recs)
    (let* ((name (id-string (name-id n)))
           (path (map id-string (name-path n)))
           (rec (type-exists? name path container-class src level type-recs)))
      (if (class-record? rec)
          (make-ref-type (car (class-record-name rec))
                         (cdr (class-record-name rec)))
          (make-ref-type name (if (null? path)
                                  (send type-recs lookup-path name (lambda () null)) path)))))

  
  ;; type-exists: string (list string) (U (list string) #f) src symbol type-records -> (U record procedure)
  (define (type-exists? name path container-class src level type-recs)
    (send type-recs get-class-record (cons name path) container-class
          ((get-importer type-recs) (cons name path) type-recs level src)))
    
  ;; is-interface?: (U type (list string) 'string) type-records-> boolean
  (define (is-interface? t type-recs)
    (not (class-record-class? 
          (get-record (send type-recs get-class-record t) type-recs))))
  
  ;;Is c1 a subclass of c2?
  ;; is-subclass?: (U type (list string) 'string) ref-type type-records -> boolean
  (define (is-subclass? c1 c2 type-recs)
    (or (type=? object-type c2)
        (let ((cr (get-record (send type-recs get-class-record c1) type-recs)))
          (member (cons (ref-type-class/iface c2) (ref-type-path c2))
                  (class-record-parents cr)))))

  ;Does c1 implement c2?
  ;; implements?: (U type (list string) 'string) ref-type type-records -> boolean
  (define (implements? c1 c2 type-recs)
    (let ((cr (get-record (send type-recs get-class-record c1) type-recs)))
      (member (cons (ref-type-class/iface c2) (ref-type-path c2))
              (class-record-ifaces cr))))

  ;;Is class1 a subclass or equal to class2?
  ;is-eq-subclass: type type type-records -> boolean
  (define (is-eq-subclass? class1 class2 type-recs)
    (or (type=? class1 class2)
        (and (reference-type? class1)
             (reference-type? class2)
             (is-subclass? class1 class2 type-recs))))
  
;                                                                                                          
;                                                                                                          
;                                                                                                          
;            ;;;                                                                                 ;         
;     ;;;;     ;                                    ;;;;;                                        ;         
;    ;    ;    ;                                    ;    ;;                                      ;         
;   ;;         ;                                    ;     ;                                      ;         
;   ;          ;     ;;;;    ;;;;    ;;;;           ;     ;  ;;;;     ;;;    ;;;;    ; ;;;   ;;; ;   ;;;;  
;   ;          ;         ;  ;    ;  ;    ;          ;    ;;  ;  ;;   ;   ;  ;;  ;;   ;;     ;;  ;;  ;    ; 
;   ;          ;     ;;;;;  ;;      ;;              ;;;;;;  ;    ;  ;       ;    ;   ;      ;    ;  ;;     
;   ;          ;    ;;   ;   ;;;;    ;;;;           ;    ;  ;;;;;;  ;       ;    ;   ;      ;    ;   ;;;;  
;   ;;         ;    ;    ;       ;       ;          ;     ; ;       ;       ;    ;   ;      ;    ;       ; 
;    ;    ;    ;    ;   ;;  ;    ;  ;    ;          ;     ;  ;   ;   ;   ;  ;;  ;;   ;      ;;  ;;  ;    ; 
;     ;;;;   ;;;;;   ;;; ;   ;;;;    ;;;;           ;      ;  ;;;     ;;;    ;;;;    ;       ;;; ;   ;;;;  
;                                                                                                          
;                                                                                                          
;                                                                                                          
    
  ;; (make-class-record (list string) (list symbol) boolean boolean (list field-record) 
  ;;                    (list method-records) (list inner-record) (list (list strings)) (list (list strings)))
  ;; After full processing fields and methods should contain all inherited fields 
  ;; and methods.  Also parents and ifaces should contain all super-classes/ifaces
  (define-struct class-record (name modifiers class? object? fields methods inners parents ifaces) #:mutable #:transparent)

  (define interactions-record (make-class-record (list "interactions") null #f #f null null null null null))
  
  ;; (make-field-record string (list symbol) bool (list string) type)
  (define-struct field-record (name modifiers init? class type) #:mutable #:transparent)
  
  ;; (make-method-record string (list symbol) type (list type) (list type) (U bool method-record) string)
  (define-struct method-record (name modifiers rtype atypes throws override class) #:mutable #:transparent)

  ;;(make-inner-record string string (list symbol) bool)
  (define-struct inner-record (name full-name modifiers class?) #:mutable #:transparent)

  ;;(make-scheme-record string (list string) path (list dynamic-val))
  (define-struct scheme-record (name path dir provides) #:mutable #:transparent)
  
  ;;(make-dynamic-val (U type method-contract unknown-ref))
  (define-struct dynamic-val (type) #:mutable #:transparent)
  
  ;;(make-unknown-ref (U method-contract field-contract))
  (define-struct unknown-ref (access) #:mutable #:transparent)
  
  ;;(make-method-contract string type (list type) (U #f string))
  (define-struct method-contract (name return args prefix) #:mutable #:transparent)
  
  ;;(make-field-contract string type)
  (define-struct field-contract (name type) #:mutable #:transparent)
  
;                                                                                      
;                                                                            ;;        
;    ;                                                                        ;        
;    ;                                                                        ;        
;   ;;;;; ;;; ;;;; ;;;    ;;;          ; ;;;   ;;;    ;;;    ;;;   ; ;;;   ;;;;   ;;;  
;    ;     ;   ;  ;   ;  ;   ;          ;     ;   ;  ;   ;  ;   ;   ;     ;   ;  ;   ; 
;    ;     ;   ;  ;   ;  ;;;;;  ;;;;;   ;     ;;;;;  ;      ;   ;   ;     ;   ;   ;;;  
;    ;      ; ;   ;   ;  ;              ;     ;      ;      ;   ;   ;     ;   ;      ; 
;    ;   ;  ;;;   ;   ;  ;   ;          ;     ;   ;  ;   ;  ;   ;   ;     ;   ;  ;   ; 
;     ;;;    ;    ;;;;    ;;;          ;;;;    ;;;    ;;;    ;;;   ;;;;    ;;; ;  ;;;  
;            ;    ;                                                                    
;            ;    ;                                                                    
;          ;;    ;;;                                                                   
                                                                                                                                                  
  ;Class to store various information per package compilation
  (define type-records 
    (class object%
      
      (field (importer 
              (lambda () 
                (error 'internal-error "type-records importer field was not set"))))
      
      ;Stores type information and require syntax per compile or execution
      (define records (make-hash))
      (define requires (make-hash))
      (define package-contents (make-hash))
      
      ;Stores per-class information accessed by location
      (define class-environment (make-hasheq))
      (define class-require (make-hasheq))

      (define compilation-location (make-hasheq))
      
      (define class-reqs null)
      (define location #f)
      
      ;add-class-record: class-record -> void
      (define/public (add-class-record r)
        (hash-set! records (class-record-name r) r))
      ;add-to-records: (list string) ( -> 'a) -> void
      (define/public (add-to-records key thunk)
        (hash-set! records key thunk))
      
      ;; get-class-record: (U type (list string) 'string) (U (list string) #f) ( -> 'a) -> 
      ;;                                            (U class-record scheme-record procedure)
      (define/public get-class-record
        (lambda (ctype [container #f] [fail (lambda () null)])
          ;(printf "get-class-record: ctype->~a container->~a ~n" ctype container)
          (let*-values (((key key-path) (normalize-key ctype))
                        ((key-inner) (when (cons? container) (string-append (car container) "." key)))
                        ((outer-record) (when (cons? container) (get-class-record container)))
                        ((path) (if (null? key-path) (lookup-path key (lambda () null)) key-path))
                        ((inner-path) (if (null? key-path) (lookup-path key-inner (lambda () null)) key-path))
                        ((new-search)
                         (lambda ()
                           (cond
                             ((null? path) (fail))
                             (else
                              (let ((back-path (reverse path)))
                                (search-for-record key (car back-path)
                                                   (reverse (cdr back-path)) (lambda () #f) fail)))))))
            ;(printf "key ~a key-path ~a path ~a location ~a ~n" key key-path path location)
            ;(printf "get-class-record: ~a~n" ctype)
            ;(hash-table-for-each records (lambda (k v) (printf "~a -> ~a~n" k v)))
            (cond
              ((and container 
                    (not (null? outer-record))
                    (not (eq? outer-record 'in-progress))
                    (member key (map inner-record-name (class-record-inners (get-record outer-record this)))))
               (hash-ref records (cons key-inner (cdr container)) fail))
              ((and container (not (null? outer-record)) (eq? outer-record 'in-progress))
               (let ((res (hash-ref records (cons key-inner inner-path) #f)))
                 (or res
                     (hash-ref records (cons key path) new-search))))
              (else
               (hash-ref records (cons key path) new-search))))))

      ;normalize-key: (U 'string ref-type (list string)) -> (values string (list string))
      (define/private (normalize-key ctype)
        (cond
          ((eq? ctype 'string) (values "String" `("java" "lang")))
          ((ref-type? ctype) (values (ref-type-class/iface ctype) (ref-type-path ctype)))
          ((cons? ctype) (values (car ctype) (cdr ctype)))
          (else (values ctype null))))
      
      ;search-for-record string string (list string) (-> #f) (-> 'a) -> class-record
      (define/private (search-for-record class-name new-prefix path test-fail fail)
        (let* ((new-class-name (string-append new-prefix "." class-name))
               (rec? (hash-ref records (cons new-class-name path) test-fail))
               (back-path (reverse path)))
          (cond
            (rec? rec?)
            ((null? path) (fail))
            (else (search-for-record new-class-name (car back-path) (reverse (cdr back-path)) test-fail fail)))))                  
      
      ;add-package-contents: (list string) (list string) -> void
      (define/public (add-package-contents package classes)
        (let ((existing-classes (hash-ref package-contents package null)))
          (if (null? existing-classes)
              (hash-set! package-contents package classes)
              (hash-set! package-contents package (non-dup-append classes existing-classes)))))

      (define/private (non-dup-append cl pa)
        (cond
          ((null? cl) pa)
          ((member (car cl) pa) (non-dup-append (cdr cl) pa))
          (else (cons (car cl) (non-dup-append (cdr cl) pa)))))
      
      ;get-package-contents: (list string) ( -> 'a) -> (list string)
      (define/public (get-package-contents package fail)
        (hash-ref package-contents package fail))
      
      ;add-to-env: string (list string) file -> void
      (define/public (add-to-env class path loc)
        #;(printf "add-to-env class ~a path ~a loc ~a~n~n" class path loc)
        (unless (hash-ref (hash-ref class-environment loc
                                    (lambda () 
                                      (let ([new-t (make-hash)])
                                        (hash-set! class-environment loc new-t)
                                        new-t)))
                          class #f)
          (hash-set! (hash-ref class-environment loc) class path)))
      
      ;Returns the environment of classes for the current location
      ;get-class-env: -> (list string)
      (define/public (get-class-env)
        (hash-map (hash-ref class-environment location) (lambda (key val) key)))
      
      (define (env-failure)
        (error 'class-environment "Internal Error: environment does not have location"))
      
      ;lookup-path: string ( -> 'a) -> (U (list string) #f)
      (define/public (lookup-path class fail)
        #;(printf "class ~a location ~a~n" class location)
        #;(printf "lookup ~a~n" class)
        #;(hash-for-each (hash-ref class-environment location)
                         (lambda (k v) (printf "~a -> ~a~n" k v)))
        (if location
            (hash-ref (hash-ref class-environment location env-failure)
                      class fail)
            (fail)))
      
      ;add-require-syntax: (list string) (list syntax syntax) -> void
      (define/public (add-require-syntax name syn)
        (get-require-syntax #t name (lambda () (hash-set! requires (cons #t name) (car syn))))
        (get-require-syntax #f name (lambda () (hash-set! requires (cons #f name) (cadr syn)))))
      
      (define (syntax-fail)
        (error 'syntax "Internal Error: syntax did not have given req"))
      
      ;get-require-syntax: bool (list string) . ( -> 'a)  -> syntax
      (define/public (get-require-syntax prefix? name . fail)
        #;(printf "~a~n" (list prefix? name))
        (hash-ref requires (cons prefix? name) (if (null? fail) syntax-fail (car fail))))
        
      ;add-class-req: name boolean location -> void
      (define/public (add-class-req name pre loc)
        ;(printf "add-class-req ~S~n" (list name pre loc))
        (hash-set! (hash-ref class-require
                             loc
                             (lambda () (let ((new-t (make-hash)))
                                          (hash-set! class-require loc new-t)
                                          new-t)))
                   name pre))
      
      ;require-fail
      (define (require-fail)
        (error 'require-prefix "Internal Error: require does not have location"))

      ;require-prefix?: (list string) ( -> 'a) -> bool
      (define/public (require-prefix? name fail)
        ;(printf "prefix? ~a~n" (list name location))
        ;(pretty-print class-require)
        (hash-ref (hash-ref class-require location require-fail) name fail))
      
      (define/private (member-req req reqs)
        (and (not (null? reqs))
             (or (and (equal? (req-class req) (req-class (car reqs)))
                      (equal? (req-path req) (req-path (car reqs))))
                 (member-req req (cdr reqs)))))

      (define/public (set-compilation-location loc dir)
        ;(printf "SETTING COMPILATION LOCATION: ~A ~A~n" loc dir)
        (hash-set! compilation-location loc dir))
      (define/public (get-compilation-location)
        (hash-ref compilation-location location 
                  (lambda () (error 'get-compilation-location "Internal error: location not found"))))
      (define/public (set-composite-location name dir) (hash-set! compilation-location name dir))
      (define/public (get-composite-location name)
        ;(printf "get-composite-location for ~a~n" name)
        ;(hash-for-each compilation-location
        ;                     (lambda (k v) (printf "~a -> ~a~n" k v)))
        (hash-ref compilation-location name 
                  (lambda () (error 'get-composite-location "Internal error: name not found"))))
      
      (define/public (add-req req)
        (unless (member-req req class-reqs)
          (set! class-reqs (cons req class-reqs))))
      (define/public (get-class-reqs) class-reqs)
      (define/public (set-class-reqs reqs) (set! class-reqs reqs))

      (define/public (set-location2! l) (set! location l))
      (define/public (set-location! l)
        ;(printf "WARNING!!! Setting location:~A~n" l)
        (set! location l))
      (define/public (get-location) location)

      (define interaction-package null)
      (define interaction-fields null)
      (define interaction-boxes null)      
      (define execution-loc #f)
      
      (define/public (set-interactions-package p) (set! interaction-package p))
      (define/public (get-interactions-package) interaction-package)
      (define/public (add-interactions-field rec)
        (set! interaction-fields (cons rec interaction-fields)))
      (define/public (get-interactions-fields)
        interaction-fields)
      (define/public (clear-interactions)
        (set! interaction-fields null))
      (define/public (add-interactions-box box)
        (set! interaction-boxes (cons box interaction-boxes)))
      (define/public (get-interactions-boxes) (reverse interaction-boxes))
      (define/public (set-execution-loc! loc) (set! execution-loc loc))
      
      (define/public (give-interaction-execution-names)
        (when execution-loc
          (hash-for-each (hash-ref class-environment execution-loc)
                         (lambda (k v) (add-to-env k v 'interactions)))
          (set! execution-loc #f)))
      
      (define test-classes null)
      (define/public (add-test-class name) 
        (set! test-classes (cons name test-classes)))
      (define/public (get-test-classes) test-classes)
      
      (super-instantiate ())))
  
  (define get-importer (class-field-accessor type-records importer))
  (define set-importer! (class-field-mutator type-records importer))

;                                                          

;                                                          
;     ;;;;            ;       ;                            
;    ;    ;           ;       ;                            
;   ;        ;;;;   ;;;;;;  ;;;;;;   ;;;;    ; ;;    ;;;;  
;   ;        ;  ;;    ;       ;      ;  ;;   ;;  ;  ;    ; 
;   ;    ;; ;    ;    ;       ;     ;    ;   ;      ;;     
;   ;     ; ;;;;;;    ;       ;     ;;;;;;   ;       ;;;;  
;   ;     ; ;         ;       ;     ;        ;           ; 
;    ;    ;  ;   ;    ;       ;      ;   ;   ;      ;    ; 
;     ;;;;    ;;;      ;;;     ;;;    ;;;    ;       ;;;;  
;                                                          
;                                                          
  
  ;get-record: (U class-record procedure) type-records -> class-record
  (define (get-record rec type-recs)
    (cond
      ((procedure? rec) 
       (let ((location (send type-recs get-location)))
         (begin0 (rec) 
                 (send type-recs set-location! location))))
      (else rec)))
  
  ;; get-field-record: string class-record (-> 'a) -> field-record
  (define (get-field-record fname c fail)
    (let ((frec (filter (lambda (f)
                          (string=? (field-record-name f) fname))
                        (class-record-fields c))))
      (cond
        ((null? frec) (fail))
        (else (car frec)))))

  ;get-field-records: class-record -> (list field-record)
  (define (get-field-records c) (class-record-fields c))
  
  ;; get-method-records: string class-record type-records -> (list method-record)
  (define (get-method-records mname c type-recs)
    (filter (lambda (m)
              (string=? (method-record-name m) mname))
            (if (class-record-class? c)
                (class-record-methods c)
                (append (class-record-methods c) (get-object-methods type-recs)))))
  
  (define (get-object-methods type-recs)
    (class-record-methods (send type-recs get-class-record object-type)))

  ;remove-dups: (list method-record) -> (list method-record)
  (define (remove-dups methods)
    (cond
      ((null? methods) methods)
      ((meth-member? (car methods) (cdr methods))
       (remove-dups (cdr methods)))
      (else (cons (car methods) (remove-dups (cdr methods))))))

  ;meth-member? method-record (list method-record) -> bool
  (define (meth-member? meth methods)
    (and (not (null? methods))
         (or (andmap type=? (method-record-atypes meth) 
                            (method-record-atypes (car methods)))
             (meth-member? meth (cdr methods)))))

  ;depth: 'a int (listof 'a) -> (U int #f)
  ;The position in elt-list that elt is at, starting with 1
  (define (depth elt start elt-list)
    (letrec ((d 
              (lambda (elt-list cnt)
                #;(printf "d: elt ~a elt-list ~a~n" elt elt-list)
                (cond
                  ((null? elt-list) +inf.0)
                  ((equal? (car elt-list) elt) cnt)
                  (else (d (cdr elt-list) (add1 cnt)))))))
      (d elt-list start)))

  ;consolidate-lists: (listof (listof alpha)) -> (listof (listof alpha))
  (define (consolidate-lists lsts)
    (cond
      ((or (null? lsts) (null? (cdr lsts))) lsts)
      ((contained-in? (car lsts) (cdr lsts))
       (consolidate-lists (cdr lsts)))
      (else
       (cons (car lsts) (consolidate-lists (cdr lsts))))))
  
  ;contained-in? (listof alpha) (listof (listof alpha)) -> boolean
  (define (contained-in? current rest)
    (and (not (null? rest))
         (or (subset? (reverse current)
                      (reverse (car rest)))
             (contained-in? current (cdr rest)))))
  
  (define (subset? smaller bigger)
    (or (null? smaller)
        (and (equal? (car smaller) (car bigger))
             (subset? (cdr smaller) (cdr bigger)))))
  
  ;iface-depth: (list string) (list (list string)) type-records -> int
  (define (iface-depth elt ifaces type-recs)
    (if (= 1 (length ifaces))
        1
        (let* ([iface-trees (map (lambda (iface)
                                  (cons iface
                                        (class-record-parents 
                                         (get-record (send type-recs get-class-record iface)
                                                     type-recs))))
                                ifaces)]
               [sorted-ifaces (sort iface-trees
                                    (lambda (a b) (< (length a) (length b))))]
               [ifaces (consolidate-lists sorted-ifaces)])
          #;(printf "iface-depth ~a ~a ~a ~n" elt 
                    iface-trees (map (lambda (i-list) (depth elt 0 i-list)) iface-trees))
          (if (null? ifaces)
              0
              (apply min (map (lambda (i-list) (depth elt 0 i-list)) ifaces))))))
  
  ;conversion-steps: type type -> int
  (define (conversion-steps from to type-recs)
    #;(printf "conversion-steps ~a ~a~n" from to)
    (cond
      ((ref-type? from)
       (let* ((to-name (cons (ref-type-class/iface to) (ref-type-path to)))
              (from-class (send type-recs get-class-record from))
              (from-class-parents (class-record-parents from-class))
              (from-class-ifaces (class-record-ifaces from-class)))
         (cond
           ((eq? to 'dynamic) (length from-class-parents))
           ((null? from-class-parents) 
            (iface-depth to-name from-class-ifaces type-recs))
           ((null? from-class-ifaces)
            (depth to-name 1 from-class-parents))
           (else (min (depth to-name 1 from-class-parents)
                      (iface-depth to-name from-class-ifaces type-recs))))))
      ((array-type? from)
       (cond
         ((array-type? to)
          (conversion-steps (array-type-type from) (array-type-type to) type-recs))
         (else
          (add1 (conversion-steps (array-type-type from) to type-recs)))))
      (else 
       (case from
         ((byte) (depth to 1 '(short int long float double)))
         ((char) (depth to 1 '(byte short int long float double)))
         ((short) (depth to 1 '(int long float double)))
         ((int) (depth to 1 '(long float double)))
         ((long) (depth to 1 '(float double)))
         (else 1))
       )))
  
  ;number-assign-conversion: (list type) (list type) type-records -> int
  (define (number-assign-conversions site-args method-args type-recs)
    (cond
      ((null? site-args) 0)
      ((and (assignment-conversion (car method-args) (car site-args) type-recs)
            (not (type=? (car site-args) (car method-args))))
       (let ((step (conversion-steps (car site-args) (car method-args) type-recs)))
         #;(printf "steps for ~a ~a~n" (car site-args) step)
         (+ step (number-assign-conversions (cdr site-args) (cdr method-args) type-recs))))
      (else (number-assign-conversions (cdr site-args) (cdr method-args) type-recs))))
  
  ;; resolve-overloading: (list method-record) (list type) (-> 'a) (-> 'a) (-> 'a) type-records-> method-record
  (define (resolve-overloading methods arg-types arg-count-fail method-conflict-fail  no-method-fail type-recs)
    #;(print-struct #t)
    (let* ((a (length arg-types))
           (m-atypes method-record-atypes)
           (a-convert? (lambda (t1 t2) (assignment-conversion t1 t2 type-recs)))
           (methods (remove-dups (filter (lambda (mr) (= a (length (m-atypes mr)))) methods)))
           (methods-same (filter (lambda (mr) 
                                   (andmap type=? (m-atypes mr) arg-types))
                                 methods))
           (assignable (filter (lambda (mr)
                                 (andmap a-convert? (m-atypes mr) arg-types))
                               methods))
           (sort (lambda (l p) (sort l p)))
           (assignable-count (sort
                              (map (lambda (mr)
                                     #;(printf "assigning conversions for ~a~n" (m-atypes mr))
                                     (list (number-assign-conversions arg-types (m-atypes mr) type-recs)
                                           mr))
                                   assignable)
                              (lambda (i1 i2) (< (car i1) (car i2))))))
      #;(printf "~a~n" assignable-count)
      (cond
        ((null? methods) (arg-count-fail))
        ((= 1 (length methods-same)) (car methods-same))
        ((> (length methods-same) 1) (method-conflict-fail))
        ((null? assignable) (no-method-fail))
        ((= 1 (length assignable)) (car assignable))
        ((= (car (car assignable-count))
            (car (cadr assignable-count))) (method-conflict-fail))
        (else (cadr (car assignable-count))))))

  ;module-has-binding?: scheme-record string (-> void) -> void
  ;module-has-binding raises an exception when variable is not defined in mod-ref
  (define (module-has-binding? mod-ref variable fail)
    (let ((var (string->symbol (java-name->scheme variable))))
      (or (memq var (scheme-record-provides mod-ref))
          (let ((mod-syntax (datum->syntax #f
                                           `(,#'module m racket/base
                                                       (require ,(generate-require-spec (java-name->scheme (scheme-record-name mod-ref))
                                                                                        (scheme-record-path mod-ref)))
                                                       ,var)
                                           #f)))
            (with-handlers ((exn? (lambda (e) (fail))))
              (parameterize ([current-namespace (make-base-namespace)])
                (expand mod-syntax)))
            (set-scheme-record-provides! mod-ref (cons var (scheme-record-provides mod-ref)))))))
          
  ;generate-require-spec: string (list string) -> (U string (list symbol string+))
  (define (generate-require-spec name path)
    (let ((mod (string-append name ".rkt")))
      (cond
        ((null? path) mod)
        ((equal? (car path) "lib")  `(lib ,mod ,@(cdr path)))
        (else `(file ,(build-path (apply build-path path) mod))))))
  
  ;java-name->scheme: string -> string
  (define (java-name->scheme name)
    (cond
      ((regexp-match "[a-zA-Z0-9]*To[A-Z0-9]*" name)
       (java-name->scheme (regexp-replace "To" name "->")))
      ((regexp-match "[a-zA-Z0-9]+P$" name)
       (java-name->scheme (regexp-replace "P$" name "?")))
      ((regexp-match "[a-zA-Z0-9]+Set$" name)
       (java-name->scheme (regexp-replace "Set$" name "!")))
      ((regexp-match "[a-zA-Z0-9]+Obj$" name)
       (java-name->scheme (regexp-replace "Obj$" name "%")))
      ((regexp-match "[a-z0-9]+->[A-Z]" name) =>
       (lambda (substring)
         (let ((char (car (regexp-match "[A-Z]" (car substring)))))
           (java-name->scheme (regexp-replace (string-append "->" char) name
                                              (string-append "->" (string (char-downcase (car (string->list char))))))))))
      ((regexp-match "[a-z0-9]+[A-Z]" name) =>
       (lambda (substring)
         (let ((char (car (string->list (car (regexp-match "[A-Z]" (car substring))))))
               (remainder (car (regexp-match "[a-z0-9]+" (car substring)))))
           (java-name->scheme (regexp-replace (car substring) name 
                                              (string-append remainder "-" (string (char-downcase char))))))))
      (else name)))

  (define (inner-rec-member name inners)
    (member name (map inner-record-name inners)))
                  
;                                          
;             ;                ;;          
;                             ;            
;     ;;;                     ;            
;       ;                     ;            
;       ;   ;;;     ; ;;;   ;;;;;    ;;;;  
;       ;     ;     ;;   ;    ;     ;;  ;; 
;       ;     ;     ;    ;    ;     ;    ; 
;       ;     ;     ;    ;    ;     ;    ; 
;       ;     ;     ;    ;    ;     ;    ; 
;   ;  ;;     ;     ;    ;    ;     ;;  ;; 
;    ;;;    ;;;;;   ;    ;    ;      ;;;;  
;                                          

  
  (define type-version "version5")
  (define type-length 11)
  
  ;; read-record: path -> (U class-record #f)
  (define (read-record filename)
    #;(printf "~a ~a ~n" filename 
            (>= (file-or-directory-modify-seconds (build-path filename))
                (file-or-directory-modify-seconds (collection-file-path "contract.rkt" "racket"))))
    (parse-record (call-with-input-file filename read)
                  #:up-to-date?
                  (>= (file-or-directory-modify-seconds (build-path filename))
                      (file-or-directory-modify-seconds (collection-file-path "contract.rkt" "racket")))))
  
  (define (parse-record datum #:up-to-date? [up-to-date? #t])
    (letrec ((parse-class/iface
              (lambda (input)
                (and (= (length input) type-length)
                     (equal? type-version (list-ref input 9))
                     (or (equal? "ignore" (list-ref input 10))
                         (and (equal? (version) (list-ref input 10))
                              up-to-date?))
                     (make-class-record (list-ref input 1)
                                        (list-ref input 2)
                                        (symbol=? 'class (car input))
                                        (list-ref input 3)
                                        (map parse-field (list-ref input 4))
                                        (map parse-method (list-ref input 5))
                                        (map parse-inner (list-ref input 6))
                                        (list-ref input 7)
                                        (list-ref input 8)))))
             (parse-field
              (lambda (input)
                (make-field-record (car input)
                                   (cadr input)
                                   #f
                                   (caddr input)
                                   (parse-type (cadddr input)))))
             (parse-method
              (lambda (input)
                (make-method-record (car input)
                                    (cadr input)
                                    (parse-type (caddr input))
                                    (map parse-type (cadddr input))
                                    (map parse-type (list-ref input 4))
                                    #f
                                    (list-ref input 5))))
             (parse-inner
              (lambda (input)
                (make-inner-record (car input)
                                   (cadr input)
                                   (caddr input)
                                   (symbol=? 'class (cadddr input)))))
             (parse-type
              (lambda (input)
                (cond
                  ((symbol? input) input)
                  ((number? (car input)) 
                   (make-array-type (parse-type (cadr input)) (car input)))
                  (else
                   (make-ref-type (car input) (cdr input)))))))
      (parse-class/iface datum)))
  
  ;; write-record: class-record port->
  (define (write-record rec port)
    (pretty-print (record->list rec) port))
  
  (define (record->list r)
    (letrec ((record->list
              (lambda (r)
                (list
                 (if (class-record-class? r)
                     'class
                     'interface)
                 (class-record-name r)
                 (class-record-modifiers r)
                 (class-record-object? r)
                 (map field->list (class-record-fields r))
                 (map method->list 
                      (let* ((kept-overrides null)
                            (methods
                             (filter 
                              (compose not
                                       (lambda (meth-rec) 
                                         (and (method-record-override meth-rec)
                                              (or (equal? (method-record-modifiers meth-rec)
                                                          (method-record-modifiers (method-record-override meth-rec)))
                                                  (not (set! kept-overrides (cons (method-record-override meth-rec) kept-overrides)))))))
                              (class-record-methods r))))
                        (filter (compose not (lambda (m) (memq m kept-overrides))) methods)))
                 (map inner->list (class-record-inners r))
                 (class-record-parents r)
                 (class-record-ifaces r)
                 type-version
                 (version))))
             (field->list
              (lambda (f)
                (list
                 (field-record-name f)
                 (field-record-modifiers f)
                 (field-record-class f)
                 (type->list (field-record-type f)))))
             (method->list
              (lambda (m)
                (list
                 (method-record-name m)
                 (method-record-modifiers m)
                 (type->list (method-record-rtype m))
                 (map type->list (method-record-atypes m))
                 (map type->list (method-record-throws m))
                 (method-record-class m))))
             (inner->list
              (lambda (i)
                (list (inner-record-name i)
                      (inner-record-full-name i)
                      (inner-record-modifiers i)
                      (if (inner-record-class? i) 'class 'interface))))
             (type->list
              (lambda (t)
                (cond
                  ((symbol? t) t)
                  ((ref-type? t) (cons (ref-type-class/iface t) (ref-type-path t)))
                  ((array-type? t)
                   (list (array-type-dim t) (type->list (array-type-type t))))))))
      (record->list r)))
  )
