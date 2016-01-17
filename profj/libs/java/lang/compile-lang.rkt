(module compile-lang racket/base
  (require profj/compile
           racket/list
           racket/file
           racket/path
           racket/pretty)
 
  (provide compile-exceptions make-compilation-path)
  
  ;move-file-in: string string -> void
  (define (move-file-in path file)
    (let ((comp-path (build-path path "compiled" file))
          (o-path (build-path path file)))
      (cond
        ((not (file-exists? comp-path)) (copy-file o-path comp-path))
        ((< (file-or-directory-modify-seconds comp-path) (file-or-directory-modify-seconds o-path))
         (delete-file comp-path)
         (copy-file o-path comp-path))
        (else (void)))))
  
  (let ((path (collection-path "profj/libs/java/lang")))
    (with-handlers
        ((exn:fail:filesystem? 
          (lambda (exn)
            (fprintf (current-error-port) 
                     "Warning: ProfessorJ needs to be able to modify files in ~a in order to run correctly"
                     (build-path path)))))

      (unless (directory-exists? (build-path path "compiled"))
        (make-directory (build-path path "compiled")))
      (move-file-in path "Object.jinfo")
      (move-file-in path "String.jinfo")
      (move-file-in path "Throwable.jinfo")
      (move-file-in path "Comparable.jinfo")
      (for-each (lambda (file)
                  (let ((fp (build-path path "compiled" file)))
                    (when (file-exists? fp)
                      (when (< (file-or-directory-modify-seconds fp) 
                               (file-or-directory-modify-seconds (build-path path "compiled" "Object.jinfo")))
                        (delete-file (build-path path "compiled" file))))))
                (filter (lambda (file)
                          (and
                           (equal? "jinfo" (filename-extension file))
                           (not (equal? file "Object.jinfo"))
                           (not (equal? file "String.jinfo"))
                           (not (equal? file "Throwable.jinfo"))
                           (not (equal? file "Comparable.jinfo"))))
                        (directory-list (build-path path "compiled"))))
      ))
  
  ;flatten : list -> list
  (define (flatten l)
    (cond
      ((null? l) null)
      ((null? (car l)) (flatten (cdr l)))
      ((pair? (car l)) (cons (car (car l))
                             (flatten (cons (cdr (car l)) (cdr l)))))
      (else (cons (car l) (flatten (cdr l))))))
  
  (define (make-compilation-path file-name)
    (let* ((path (explode-path (normalize-path file-name)))
           (rev-path (reverse path))
           (file (car rev-path)))
      (build-path (apply build-path (reverse (cdr rev-path)))
                  "compiled" (path-replace-suffix file ".jinfo"))))
  
  (define (write-out-jinfos files jinfos)
    (for-each (lambda (file-name jinfo)
                (call-with-output-file (make-compilation-path file-name)
                  (lambda (port) (write-record jinfo port))))
              files jinfos))
  
  (define (clear-jinfos files)
    (for-each (lambda (file-name)
                (when (file-exists? (make-compilation-path file-name))
                  (delete-file (make-compilation-path file-name))))
              files))
  
  ;write-out-files : (list string) (list syntax) -> void
  ;Writes out module stubes to file: assumes package lang for now
  (define (write-out-files names bodies)
    (for-each (lambda (name mod) 
                (unless (file-exists? (string-append name ".ss"))
                  (call-with-output-file (string-append name ".ss")
                    (lambda (port) (pretty-print (syntax->datum mod) port))
                    'truncate/replace)))
              names
              (map (lambda (name provide)
                     (datum->syntax #f
                                    `(module ,(string->symbol name) racket/base
                                       (require "Object-composite.ss")
                                       ,provide)
                                    #f))
                   names (map get-provides bodies))))
 
  (define foo #t)
  (define (compile-exceptions so)
    (set-syntax-location so)
    (let* ((files (filter (lambda (f) (regexp-match "Exception[.]java$" (path->string f)))
                          (directory-list (build-path (collection-path "profj") "libs" "java" "lang")))))
      (let ((cur-dir (current-directory)))
        (current-directory (build-path (collection-path "profj") "libs" "java" "lang"))
        (clear-jinfos files)
        (let* ((compiled (cdr (car (compile-files (list (list files (list "java" "lang"))) #f 'full))))
               (compiled-exceptions (flatten (car compiled)))
               (compiled-pieces (map (lambda (cu) (reassemble-pieces (car (compilation-unit-code cu))))
                                     compiled-exceptions)))
          (write-out-files (map car compiled-pieces) (map caddr compiled-pieces))
          (write-out-jinfos files (car (cdr compiled)))
          (current-directory cur-dir)
          (datum->syntax so 
                         `(begin ,@(filter (lambda (x) x)
                                           (map (lambda (r) (get-keepable-reqs r (syntax->datum so)))
                                                       (apply append (map cadr compiled-pieces))))
                                        ,@(map caddr compiled-pieces))
                                #f)))))
  
  (define (reassemble-pieces stx)
    (syntax-case stx ()
      ((module name racket/base
         (require class runtime real ...)
         begin)
       (list (symbol->string (syntax->datum (syntax name)))
             (syntax->list #'(real ...)) 
             (syntax begin)))))
  
  (define (get-keepable-reqs req names)
    (syntax-case req (lib file)
      ((lib name "profj" "libs" "java" "lang")
       (and (not (member-name (syntax->datum (syntax name)) (cdr names))) req))
      ((file name)
       (and (not (member-name (syntax->datum (syntax name)) (cdr names))) req))
      (name #f)))
  
  (define (member-name name names)
    (cond
      ((null? names) #f)
      ((regexp-match (car names) name) #t)
      (else (member-name name (cdr names)))))
      
  (define (get-provides body)
    (syntax-case body ()
      ((begin provide impl ...) (syntax provide))))
           
   
  )
