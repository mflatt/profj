(module compile-lang-syntax racket/base
  (require (for-syntax racket/base "compile-lang.ss"))
  
  (provide compile-rest-of-lang)
  
  (define-syntax (compile-rest-of-lang stx)
    (syntax-case stx ()
      [(_ names) (compile-exceptions (syntax names))]))

  )
