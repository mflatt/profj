(module Object racket/base
  (require "Object-composite.rkt")
  (provide ObjectI Object-Mix Object)
  (provide guard-convert-Object convert-assert-Object wrap-convert-assert-Object 
           dynamic-Object/c static-Object/c wrapper stm-wrapper))
