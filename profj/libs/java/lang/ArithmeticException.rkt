(module ArithmeticException racket/base
  (require "Object-composite.rkt")
  (provide
   ArithmeticException
   guard-convert-ArithmeticException
   convert-assert-ArithmeticException
   wrap-convert-assert-ArithmeticException
   dynamic-ArithmeticException/c
   static-ArithmeticException/c))
