#lang setup/infotab

(define name "ProfessorJ")
(define tools (list (list "tool.rkt") #;(list "test-tool.rkt")))
(define tool-names '("ProfessorJ" #;"ProfessorJ Testing"))
(define install-collection "installer.rkt")
(define pre-install-collection "pre-installer.rkt")
(define get-textbook-pls
  '("textbook-pls-spec.rkt" textbook-pls))
(define scribblings '(("scribblings/htdc.scrbl" (multi-page) (language -10.5))
                      ("scribblings/profj.scrbl" () (language))))

