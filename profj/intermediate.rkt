#lang racket/base
(require "language.rkt")

(provide (all-from-out racket/base))

(generate-reader profj/intermediate intermediate)
