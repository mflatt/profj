#lang setup/infotab

(define name "ProfessorJ")
(define tools (list (list "tool.ss") #;(list "test-tool.ss")))
(define tool-names '("ProfessorJ" #;"ProfessorJ Testing"))
(define install-collection "installer.ss")
(define pre-install-collection "pre-installer.ss")
(define get-textbook-pls
  '("textbook-pls-spec.rkt" textbook-pls))
(define scribblings '(("scribblings/htdc.scrbl" (multi-page) (language -10.5))
                      ("scribblings/profj.scrbl" () (language))))

