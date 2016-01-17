(module RuntimeException racket/base
  (require "Object-composite.rkt")
  (provide
   RuntimeException
   guard-convert-RuntimeException
   convert-assert-RuntimeException
   wrap-convert-assert-RuntimeException
   dynamic-RuntimeException/c
   static-RuntimeException/c))
