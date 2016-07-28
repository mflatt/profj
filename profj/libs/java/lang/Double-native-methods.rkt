#cs
(module Double-native-methods racket/base
  
  (require racket/class)
  (require "Throwable.rkt" "String.rkt"
           #;"NumberFormatException.rkt" "NullPointerException.rkt" "RuntimeException.rkt")
  
  (provide (all-defined-out))
  
  (define (Double-parseDoubleHelper-java.lang.String-native s)
    #;(when (null? s)
      (raise (create-java-exception NullPointerException
                                    "parseDouble expected to receive String, received null value"
                                    (lambda (obj msg)
                                      (send obj NullPointerException-constructor-java.lang.String msg))
                                    (current-continuation-marks))))             
    (let* ((scheme-string (send (send s trim) get-racket-string))
           (num (string->number scheme-string)))
      (or num
          (cond
            ((equal? scheme-string "+NaN") +nan.0)
            ((equal? scheme-string "-NaN") -nan.0)
            ((equal? scheme-string "-Infinity") -inf.0)
            ((equal? scheme-string "+Infinity") +inf.0)
            (raise (create-java-exception RuntimeException
                                          (format "parseDouble given misformatted string ~a" scheme-string)
                                          (lambda (obj msg)
                                            (send obj RuntimeException-constructor-java.lang.String msg))
                                          (current-continuation-marks)))))))
  
  (define (Double-doubleToLongBits-double-native num) 
    (raise (create-java-exception RuntimeException
                                  "doubleToLongBits has not been written"
                                  (lambda (obj msg)
                                    (send obj RuntimeException-constructor-java.lang.String msg))
                                  (current-continuation-marks))))
    
  (define (Double-doubleToRawLongBits-double-native num) 
    (raise (create-java-exception RuntimeException
                                  "doubleToRawLongBits has not been written"
                                  (lambda (obj msg)
                                    (send obj RuntimeException-constructor-java.lang.String msg))
                                  (current-continuation-marks))))
  
  (define (Double-longBitsToDouble-long-native num) 
    (raise (create-java-exception RuntimeException
                                  "longBitsToDouble has not been written"
                                  (lambda (obj msg)
                                    (send obj RuntimeException-constructor-java.lang.String msg))
                                  (current-continuation-marks))))
  

  (define (Double-toString-double-boolean-native num isFloat?)
    (make-java-string (number->string num)))
  
  ;;Privates
  (define (Double-initIDs-native) (void))
  (define (Double-getNegInf-native) -inf.0)
  (define (Double-getPosInf-native) +inf.0)
  (define (Double-getNaN-native) +nan.0)
  
  )
