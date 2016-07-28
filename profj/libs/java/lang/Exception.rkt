(module Exception racket/base
  (require "Object-composite.rkt")
  (provide
   Exception
   guard-convert-Exception
   convert-assert-Exception
   wrap-convert-assert-Exception
   dynamic-Exception/c
   static-Exception/c))
