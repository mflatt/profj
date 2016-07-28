(module Comparable racket/base
  (require racket/class)
  (provide (all-defined-out))
  (define Comparable (interface () compareTo-java.lang.Object)))
