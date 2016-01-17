#lang racket/base

(require (prefix-in geo:   "geometry/installer.ss")
         (prefix-in color: "colors/installer.ss")
         (prefix-in draw:  "draw/installer.ss")
         (prefix-in idraw: "idraw/installer.ss")
         (prefix-in graph: "graphics/installer.ss"))

(provide installer)
(define (installer plthome)
  (geo:installer   plthome)
  (color:installer plthome)
  (draw:installer  plthome)
  (idraw:installer plthome)
  #;(graph:installer plthome))
