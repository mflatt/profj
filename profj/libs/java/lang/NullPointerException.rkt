(module NullPointerException racket/base
  (require "Object-composite.ss")
  (provide
   NullPointerException
   guard-convert-NullPointerException
   convert-assert-NullPointerException
   wrap-convert-assert-NullPointerException
   dynamic-NullPointerException/c
   static-NullPointerException/c))
