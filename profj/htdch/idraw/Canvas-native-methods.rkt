#lang scheme

(require (lib "profj/htdch/draw/support.rkt")
         racket/unit)

(define void-or-true (void))
(define (imperative w@t+1 w@t) w@t+1)
  
(define-values/invoke-unit/infer canvas-native@)

(provide-signature-elements canvas-native^)
