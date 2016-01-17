(module installer racket/base
  (require profj/compile
           (prefix-in colors: profj/htdch/colors/installer)
           (prefix-in geometry: profj/htdch/geometry/installer))
  (provide installer)
  
  (define (mprintf . a)
    (fprintf a (current-error-port)))
  
  (define (installer plthome)
    #;#;
    (colors:installer plthome)
    (geometry:installer plthome)
    (let ((draw-path (build-path (collection-path "profj" "htdch" "draw"))))
      (let ((javac
             (lambda (file)
               (parameterize ([current-load-relative-directory draw-path]
                              [current-directory draw-path])
                 (compile-java 'file 'file 'full
                               (build-path draw-path file)
                               #f #f)))))
        (javac "Canvas.java")
        (javac "SillyCanvas.java")
        (javac "World.java")))))
