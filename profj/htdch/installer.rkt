#lang racket/base

(require (prefix-in geo:   "geometry/installer.rkt")
         (prefix-in color: "colors/installer.rkt")
         (prefix-in draw:  "draw/installer.rkt")
         (prefix-in idraw: "idraw/installer.rkt")
         (prefix-in graph: "graphics/installer.rkt")
         (prefix-in processing: "processing/installer.rkt"))

(provide installer)
(define (installer plthome)
  (geo:installer   plthome)
  (color:installer plthome)
  (draw:installer  plthome)
  (idraw:installer plthome)
  (processing:installer plthome)
  #;(graph:installer plthome))
