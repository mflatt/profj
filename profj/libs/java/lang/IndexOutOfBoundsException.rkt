(module IndexOutOfBoundsException racket/base
  (require "Object-composite.rkt")
  (provide
   IndexOutOfBoundsException
   guard-convert-IndexOutOfBoundsException
   convert-assert-IndexOutOfBoundsException
   wrap-convert-assert-IndexOutOfBoundsException
   dynamic-IndexOutOfBoundsException/c
   static-IndexOutOfBoundsException/c))
