#cs
(module System-native-methods racket/base
  
  (provide (all-defined-out))
  
  (define (System-currentTimeMillis-native) (inexact->exact (floor (current-inexact-milliseconds))))
  
  (define (System-gc-native) (collect-garbage))
  
  (define (System-identityHashCode-java.lang.Object-native o) (eq-hash-code o))
  
  )
