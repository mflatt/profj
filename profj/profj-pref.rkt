(module profj-pref racket/base
  
  (require racket/file)
  
  (provide reset-classpath add-to-classpath get-classpath)

  ;get-classpath: -> (list string)
  (define (get-classpath)
    (append (cons (build-path 'same)
                  (get-preference 'projf:classpath (lambda () null)))
            (list (collection-path "profj" "libs"))
            (list (collection-path "profj" "htdch"))))
  
  ;reset-classpath: -> void
  (define (reset-classpath)
    (put-preferences `(profj:classpath) (list null)))
  
  ;add-to-classpath: string -> void
  (define (add-to-classpath path)
    (let ((old-classpath (get-preference 'profj:classpath (lambda () null))))
      (put-preferences `(profj:classpath) (list (cons path old-classpath)))))
  
  ;remove-from-classpath: string -> void
  (define (remove-from-classpath path)
    (let ((old-classpath (get-preference 'profj:classpath (lambda () null))))
      (put-preferences `(profj:classpath) (list (remove path old-classpath)))))
  
)
