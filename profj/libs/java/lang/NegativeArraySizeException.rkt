(module NegativeArraySizeException racket/base
  (require "Object-composite.ss")
  (provide
   NegativeArraySizeException
   guard-convert-NegativeArraySizeException
   convert-assert-NegativeArraySizeException
   wrap-convert-assert-NegativeArraySizeException
   dynamic-NegativeArraySizeException/c
   static-NegativeArraySizeException/c))
