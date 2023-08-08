#lang racket/base
(require (for-syntax racket/base)
         parser-tools/lex)

(provide generate-reader)

(define-syntax (generate-reader stx)
  (syntax-case stx ()
    [(_ lang-module level #:dynamic? allow-dynamic?)
     #`(module reader syntax/module-reader
         lang-module
         #:whole-body-readers? #t
         #:read-syntax
         (lambda (name in)
           (read-profj-syntax name in))
         #:read
         (lambda (in)
           (map syntax->datum (read-profj-syntax 'prog in)))
         #:info
         (lambda (mode default get-default)
           (case mode
             [(color-lexer) (lambda (in)
                              (define-values (lexeme category paren start end)
                                (get-syntax-token in))
                              (define revised-category
                                (case category
                                  [(literal) 'constant]
                                  [(identifier) 'symbol]
                                  [else category]))
                              (define (position-offset* p)
                                (if (position? p)
                                    (position-offset p)
                                    p))
                              (values lexeme revised-category paren
                                      (position-offset* start)
                                      (position-offset* end)))]
             [else (get-default mode default)]))
         
         (require racket/class
                  "parser.rkt"
                  (only-in "parsers/lexer.rkt" get-syntax-token)
                  "compile.rkt"
                  "parameters.rkt"
                  syntax/strip-context)
         
         (define (read-profj-syntax name in)
           (parameterize ([to-submodules #t]
                          [dynamic? #,(syntax->datum #'allow-dynamic?)])
             (define type-recs (create-type-record))
             (define cs (compile-ast (parse in name 'level)
                                     'level
                                     type-recs))
             (append
              (apply append (map compilation-unit-code cs))
              (list
               (strip-context
                #`(module jinfo racket/base
                    (provide jinfos)
                    (define jinfos
                      '#,(for/hash ([c (in-list cs)])
                           (define cname (compilation-unit-contains c))
                           (values
                            cname
                            (record->list (send type-recs get-class-record 
                                                cname
                                                #f
                                                (lambda ()
                                                  (error 'profj "error converting type info"))))))))))))))]
    [(_ lang-module level)
     #'(generate-reader lang-module level #:dynamic? #f)]))
