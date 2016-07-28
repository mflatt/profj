(module advanced-parser racket/base

  (require "general-parsing.rkt"
           "lexer.rkt"
           "../ast.rkt"
           "../parameters.rkt")
  
  (require parser-tools/yacc
           (except-in parser-tools/lex input-port)
           syntax/readerr)
    
  (provide parse-advanced parse-advanced-interactions parse-advanced-expression parse-advanced-type)
  
  (define parsers
    (parser
     (start CompilationUnit AdvancedInteractions VariableInitializer Type)
     ;;(debug "parser.output")
     (tokens java-vals special-toks Keywords Separators EmptyLiterals Operators ExtraKeywords)
     ;(terminals val-tokens special-tokens keyword-tokens separator-tokens literal-tokens operator-tokens)
     (error (lambda (tok-ok name val start-pos end-pos)
              (when ((determine-error))
                (raise-read-error (format "Parse error near <~a:~a>" name val)
                                  (file-path)
                                  (position-line start-pos)
                                  (position-col start-pos)
                                  (+ (position-offset start-pos) (interactions-offset))
                                  (- (position-offset end-pos)
                                     (position-offset start-pos))))))

     (end EOF)
     (src-pos)
     
     (grammar
      
      ;; 19.3
      (Literal
       [(INTEGER_LIT) (make-literal 'int (build-src 1) $1)]
       [(LONG_LIT) (make-literal 'long (build-src 1) $1)]
       [(FLOAT_LIT) (make-literal 'float (build-src 1) $1)]
       [(DOUBLE_LIT) (make-literal 'double (build-src 1)  $1)]
       [(TRUE_LIT) (make-literal 'boolean (build-src 1) #t)]
       [(FALSE_LIT) (make-literal 'boolean (build-src 1) #f)]
       [(CHAR_LIT) (make-literal 'char (build-src 1) $1)]
       [(STRING_LIT) (make-literal 'string 
                                   (make-src (position-line $1-start-pos)
                                             (position-col $1-start-pos)
                                             (+ (position-offset $1-start-pos) (interactions-offset))
                                             (- (position-offset (cadr $1)) (position-offset $1-start-pos))
                                             (file-path))
                                   (car $1))]
       [(NULL_LIT) (make-literal 'null (build-src 1) #f)]
       [(IMAGE_SPECIAL) (make-literal 'image (build-src 1) $1)])
      
      ;; 19.4
      (Type
       [(PrimitiveType) $1]
       [(ReferenceType) $1])
      
      (PrimitiveType
       [(NumericType) $1]
       [(boolean) (make-type-spec 'boolean 0 (build-src 1))])
      
      (NumericType
       [(IntegralType) $1]
       [(FloatingPointType) $1])
      
      (IntegralType
       [(byte) (make-type-spec 'byte 0 (build-src 1))]
       [(short) (make-type-spec 'short 0 (build-src 1))]
       [(int) (make-type-spec 'int 0 (build-src 1))]
       [(long) (make-type-spec 'long 0 (build-src 1))]
       [(char) (make-type-spec 'char 0 (build-src 1))])
      
      (FloatingPointType
       [(float) (make-type-spec 'float 0 (build-src 1))]
       [(double) (make-type-spec 'double 0 (build-src 1))])
      
      (ReferenceType
       [(Name) (make-type-spec $1 0 (build-src 1))]
       [(ArrayType) $1]
       )
            
      (ClassOrInterfaceType
       [(Name) $1])
      
      (ClassType
       [(ClassOrInterfaceType) $1])
      
      (InterfaceType
       [(ClassOrInterfaceType) $1])
      
      (ArrayType
       [(PrimitiveType Dims) (make-type-spec (type-spec-name $1) $2 (build-src 2))]
       [(Name Dims) (make-type-spec $1 $2 (build-src 2))])

      ;;19.5
      (Name
       [(IDENTIFIER) (make-name (make-id $1 (build-src 1)) null (build-src 1))]
       [(Name PERIOD IDENTIFIER)
	(make-name (make-id $3 (build-src 3 3)) 
		       (append (name-path $1) (list (name-id $1)))
		       (build-src 3))])
      ;; 19.6
      (CompilationUnit
       [(PackageDeclaration ImportDeclarations TypeDeclarations) 
        (make-package $1 (reverse $2) (reverse $3))]
       [(ImportDeclarations TypeDeclarations) (make-package #f (reverse $1) (reverse $2))]
       [(PackageDeclaration TypeDeclarations) (make-package $1 null (reverse $2))]
       [(PackageDeclaration ImportDeclarations) (make-package $1 (reverse $2) null)]
       [(PackageDeclaration) (make-package $1 null null)]
       [(ImportDeclarations) (make-package #f (reverse $1) null)]
       [(TypeDeclarations) (make-package #f null (reverse $1))]
       [() (make-package #f null null)])
      
      (AdvancedInteractions
       [(Statement) $1]
       [(FieldDeclaration) $1]
       [(Expression) $1]
       [() null])
      
      (ImportDeclarations
       [(ImportDeclaration) (list $1)]
       [(ImportDeclarations ImportDeclaration) (cons $2 $1)])

      (TypeDeclarations
       [(TypeDeclaration) (if $1
                              (list $1)
                              null)]
       [(TypeDeclarations TypeDeclaration) (if $2
                                               (cons $2 $1)
                                               $1)])
      
      (PackageDeclaration
       [(package Name SEMI_COLON) $2])
      
      (ImportDeclaration
       [(SingleTypeImportDeclaration) $1]
       [(TypeImportOnDemandDeclaration) $1])
      
      (SingleTypeImportDeclaration
       [(import Name SEMI_COLON) (make-import $2 #f (build-src 1) (build-src 3) (file-path))])
      
      (TypeImportOnDemandDeclaration
       [(import Name PERIOD * SEMI_COLON)
	(make-import $2 #t (build-src 1) (build-src 5) (file-path))])
      
      (TypeDeclaration
       [(ClassDeclaration) $1]
       [(InterfaceDeclaration) $1]
       #;[(INTERACTIONS_BOX) $1]
         #;[(CLASS_BOX) (parse-class-box $1 (build-src 1) 'advanced)]
       [(TEST_SUITE) $1]
       [(EXAMPLE) $1]
       [(SEMI_COLON) #f])
      
      ;; 19.7
      (Modifiers
       [(Modifier) (list $1)]
       [(Modifiers Modifier) (cons $2 $1)])
      
      (Modifier
       [(public) (make-modifier 'public (build-src 1))]
       [(protected) (make-modifier 'protected (build-src 1))]
       [(private) (make-modifier 'private (build-src 1))]
       [(static) (make-modifier 'static (build-src 1))]
       [(abstract) (make-modifier 'abstract (build-src 1))]
       [(final) (make-modifier 'final (build-src 1))])
       
      ;; 19.8.1
      (ClassDeclaration
       [(Modifiers class IDENTIFIER Super Interfaces ClassBody)
	(make-class-def (make-header (make-id $3 (build-src 3 3)) $1 $4 $5 null (build-src 5))
                            $6
                            (build-src 2 2)
                            (build-src 6)
                            (file-path)
                            'advanced
                            null 'top null)]
       [(class IDENTIFIER Super Interfaces ClassBody)
	(make-class-def (make-header (make-id $2 (build-src 2 2)) null $3 $4 null (build-src 4))
                            $5
                            (build-src 1)
                            (build-src 5)
                            (file-path)
                            'advanced
                            null 'top null)])
      
      (Super
       [() null]
       [(extends ClassType) (list $2)])
      
      (Interfaces
       [() null]
       [(implements InterfaceTypeList) $2])
      
      (InterfaceTypeList
       [(InterfaceType) (list $1)]
       [(InterfaceTypeList COMMA InterfaceType) (cons $3 $1)])
      
      (ClassBody
       [(O_BRACE ClassBodyDeclarations C_BRACE) (reverse $2)])
      
      (ClassBodyDeclarations
       [() null]
       [(ClassBodyDeclarations ClassBodyDeclaration)
        (cond
          ((not $2) $1)
          ((list? $2) (append $2 $1))
          (else (cons $2 $1)))])
      
      (ClassBodyDeclaration
       [(ClassMemberDeclaration) $1]
       [(StaticInitializer) $1]
       [(ConstructorDeclaration) $1]
       [(SEMI_COLON) #f])
      
      (ClassMemberDeclaration
       [(FieldDeclaration) $1]
       [(MethodDeclaration) $1])
      
      ;; 19.8.2
      (FieldDeclaration
       [(Modifiers Type VariableDeclarators SEMI_COLON)
        (map (lambda (d) (build-field-decl $1 $2 d)) (reverse $3))]
       [(Type VariableDeclarators SEMI_COLON)
        (map (lambda (d) (build-field-decl null $1 d)) (reverse $2))])

      (VariableDeclarators
       [(VariableDeclarator) (list $1)]
       #;[(VariableDeclarators COMMA VariableDeclarator) (cons $3 $1)])
      
      (VariableDeclarator
       [(VariableDeclaratorId) $1]
       [(VariableDeclaratorId = VariableInitializer)
        (make-var-init $1 $3 (build-src 3))])

      (VariableDeclaratorId
       [(IDENTIFIER)
	(make-var-decl (make-id $1 (build-src 1)) null (make-type-spec #f 0 (build-src 1)) #f (build-src 1))]
       [(IDENTIFIER Dims)
	(make-var-decl (make-id $1 (build-src 1)) null (make-type-spec #f $2 (build-src 2)) #f (build-src 2))])
			
      (VariableInitializer
       [(Expression) $1]
       [(ArrayInitializer) $1])

      ;; 19.8.3
      (MethodDeclaration
       [(MethodHeader MethodBody) (make-method (method-modifiers $1)
                                               (method-type $1)
                                               (method-type-parms $1)
                                               (method-name $1)
                                               (method-parms $1)
                                               (method-throws $1)
                                               $2
                                               #f
                                               #f
                                               (build-src 2))])

      (MethodHeader
       [(Modifiers Type MethodDeclarator) (construct-method-header $1 null $2 $3 null)]
       [(Modifiers void MethodDeclarator)
	(construct-method-header $1 
				 null 
				 (make-type-spec 'void 0 (build-src 2 2)) 
				 $3
				 null)]
       [(Type MethodDeclarator) (construct-method-header null null $1 $2 null)]
       [(void MethodDeclarator)
	(construct-method-header null
				 null 
				 (make-type-spec 'void 0 (build-src 2 2))
				 $2 
				 null)])
      
      (MethodDeclarator
       [(IDENTIFIER O_PAREN FormalParameterList C_PAREN) (list (make-id $1 (build-src 1)) (reverse $3) 0)]
       [(IDENTIFIER O_PAREN C_PAREN) (list (make-id $1 (build-src 1)) null 0)]
       [(IDENTIFIER O_PAREN FormalParameterList C_PAREN Dims) (list (make-id $1 (build-src 1)) (reverse $3) $5)]
       [(IDENTIFIER O_PAREN C_PAREN Dims) (list (make-id $1 (build-src 1)) null $4)])
      
      (FormalParameterList
       [(FormalParameter) (list $1)]
       [(FormalParameterList COMMA FormalParameter) (cons $3 $1)])
      
      (FormalParameter
       [(Type VariableDeclaratorId) (build-field-decl null $1 $2)])
            
      (MethodBody
       [(Block) $1]
       [(SEMI_COLON) #f])
      
      ;; 19.8.4
      
      (StaticInitializer
       ;; 1.1
       [(Block) (make-initialize #f $1 (build-src 1))])
      
      ;; 19.8.5
      
      (ConstructorDeclaration
       [(Modifiers ConstructorDeclarator ConstructorBody)
	(make-method $1 (make-type-spec 'ctor 0 (build-src 3)) null (car $2) 
                         (cadr $2) null $3 #f #f (build-src 3))]
       [(ConstructorDeclarator ConstructorBody)
	(make-method null (make-type-spec 'ctor 0 (build-src 2)) null (car $1)
                         (cadr $1) null $2 #f #f (build-src 2))])
      
      (ConstructorDeclarator
       [(IDENTIFIER O_PAREN FormalParameterList C_PAREN) (list (make-id $1 (build-src 1)) (reverse $3))]
       [(IDENTIFIER O_PAREN C_PAREN) (list (make-id $1 (build-src 1)) null)])
      
      (ConstructorBody
       [(O_BRACE ExplicitConstructorInvocation BlockStatements C_BRACE)
	(make-block (cons $2 (reverse $3)) (build-src 4))]
       [(O_BRACE ExplicitConstructorInvocation C_BRACE)
	(make-block (list $2) (build-src 3))]
       [(O_BRACE BlockStatements C_BRACE)
	(make-block 
	 (cons (make-call #f #f #f (make-special-name #f #f "super") null #f)
	       (reverse $2))
	 (build-src 3))]
       [(O_BRACE C_BRACE)
	(make-block
	 (list (make-call #f (build-src 1) 
			      #f (make-special-name #f #f "super") null (build-src 2)))
	 (build-src 2))])
      
      (ExplicitConstructorInvocation
       [(this O_PAREN ArgumentList C_PAREN SEMI_COLON)
	(make-call #f (build-src 5) 
		       #f (make-special-name #f (build-src 1) "this") (reverse $3) #f)]
       [(this O_PAREN C_PAREN SEMI_COLON)
	(make-call #f (build-src 4) 
		       #f (make-special-name #f (build-src 1) "this") null #f)]
       [(super O_PAREN ArgumentList C_PAREN SEMI_COLON)
	(make-call #f (build-src 5) 
		       #f (make-special-name #f (build-src 1) "super") (reverse $3) #f)]
       [(super O_PAREN C_PAREN SEMI_COLON)
	(make-call #f (build-src 4) 
		       #f (make-special-name #f (build-src 1) "super") null #f)])
      
      ;; 19.9.1
      
      (InterfaceDeclaration
       [(Modifiers interface IDENTIFIER ExtendsInterfaces InterfaceBody)
	(make-interface-def (make-header (make-id $3 (build-src 3 3)) $1 $4 null null (build-src 4))
                                $5
                                (build-src 2 2)
                                (build-src 5)
                                (file-path)
                                'advanced
                                null 'top null)]
       [(Modifiers interface IDENTIFIER InterfaceBody)
	(make-interface-def (make-header (make-id $3 (build-src 3 3)) $1 null null null (build-src 3))
                                $4
                                (build-src 2 2)
                                (build-src 4)
                                (file-path)
                                'advanced
                                null 'top null)]
       [(interface IDENTIFIER ExtendsInterfaces InterfaceBody)
       	(make-interface-def (make-header (make-id $2 (build-src 2 2)) null $3 null null (build-src 3))
                                $4
                                (build-src 1)
                                (build-src 4)
                                (file-path)
                                'advanced
                                null 'top null)]
       [(interface IDENTIFIER InterfaceBody)
	(make-interface-def (make-header (make-id $2 (build-src 2 2)) null null null null (build-src 2))
                                $3
                                (build-src 1)
                                (build-src 3)
                                (file-path)
                                'advanced
                                null 'top null)])
       
      
      (ExtendsInterfaces
       [(extends InterfaceType) (list $2)]
       [(ExtendsInterfaces COMMA InterfaceType) (cons $3 $1)])

      (InterfaceBody
       [(O_BRACE InterfaceMemberDeclarations C_BRACE) $2])
      
      (InterfaceMemberDeclarations
       [() null]
       [(InterfaceMemberDeclarations InterfaceMemberDeclaration) 
        (cond
          ((not $2) $1)
          ((list? $2) (append $2 $1))
          (else (cons $2 $1)))])
      
      (InterfaceMemberDeclaration
       [(ConstantDeclaration) $1]
       [(AbstractMethodDeclaration) $1]
       [(SEMI_COLON) #f])
      
      (ConstantDeclaration
       [(FieldDeclaration) $1])
      
      (AbstractMethodDeclaration
       [(MethodHeader SEMI_COLON) $1])
      
      ;; 19.10
      
      (ArrayInitializer
       [(O_BRACE VariableInitializers COMMA C_BRACE) (make-array-init $2 (build-src 3))]
       [(O_BRACE VariableInitializers C_BRACE) (make-array-init $2 (build-src 3))]
       [(O_BRACE COMMA C_BRACE) (make-array-init null (build-src 3))]
       [(O_BRACE C_BRACE) (make-array-init null (build-src 2))])
      
      (VariableInitializers
       [(VariableInitializer) (list $1)]
       [(VariableInitializers COMMA VariableInitializer) (cons $3 $1)])
      
      ;; 19.11
      
      (Block
       [(O_BRACE BlockStatements C_BRACE) (make-block (reverse $2) (build-src 3))]
       [(O_BRACE C_BRACE) (make-block null (build-src 2))])
      
      (BlockStatements
       [(BlockStatement) (cond
			  ((list? $1) $1)
			  (else (list $1)))]
       [(BlockStatements BlockStatement) (cond
                                           ((list? $2)
                                            (append (reverse $2) $1))
                                           (else
                                            (cons $2 $1)))])
      
      (BlockStatement
       [(LocalVariableDeclarationStatement) $1]
       [(Statement) $1])
      
      (LocalVariableDeclarationStatement
       [(LocalVariableDeclaration SEMI_COLON) $1])
      
      (LocalVariableDeclaration
       [(Type VariableDeclarators)
        (map (lambda (d) (build-field-decl null $1 d)) (reverse $2))])
      
      (Statement
       [(StatementWithoutTrailingSubstatement) $1]
       [(IfThenStatement) $1]
       [(IfThenElseStatement) $1]
       [(WhileStatement) $1]
       [(ForStatement) $1])
      
      (StatementNoShortIf
       [(StatementWithoutTrailingSubstatement) $1]
       [(IfThenElseStatementNoShortIf) $1]
       [(WhileStatementNoShortIf) $1]
       [(ForStatementNoShortIf) $1])
      
      (StatementWithoutTrailingSubstatement
       [(Block) $1]
       [(EmptyStatement) $1]
       [(Assignment SEMI_COLON) $1]
       [(ExpressionStatement) $1]
       [(DoStatement) $1]
       [(BreakStatement) $1]
       [(ContinueStatement) $1]
       [(ReturnStatement) $1])
      
      (EmptyStatement
       [(SEMI_COLON) (make-block null (build-src 1))])
            
      (ExpressionStatement
       [(StatementExpression SEMI_COLON) $1])
      
      (StatementExpression
       [(PreIncrementExpression) $1]
       [(PreDecrementExpression) $1]
       [(PostIncrementExpression) $1]
       [(PostDecrementExpression) $1]
       [(MethodInvocation) $1]
       [(ClassInstanceCreationExpression) $1])
      
      (IfThenStatement
       [(if O_PAREN Expression C_PAREN Statement) (make-ifS $3 $5 #f (build-src 1) (build-src 5))])
      
      (IfThenElseStatement
       [(if O_PAREN Expression C_PAREN StatementNoShortIf else Statement)
	(make-ifS $3 $5 $7 (build-src 1) (build-src 7))])
      
      (IfThenElseStatementNoShortIf
       [(if O_PAREN Expression C_PAREN StatementNoShortIf else StatementNoShortIf)
	(make-ifS $3 $5 $7 (build-src 1) (build-src 7))])
      
      (WhileStatement
       [(while O_PAREN Expression C_PAREN Block)
        (make-while $3 $5 (build-src 5))])
      
      (WhileStatementNoShortIf
       [(while O_PAREN Expression C_PAREN Block #;StatementNoShortIf)
	(make-while $3 $5 (build-src 5))])
      
      (DoStatement
       [(do Block #;Statement while O_PAREN Expression C_PAREN SEMI_COLON)
	(make-doS $2 $5 (build-src 7))])
      
      (ForStatement
       [(for O_PAREN ForInit SEMI_COLON Expression SEMI_COLON ForUpdate C_PAREN Block #;Statement)
	(make-for $3 $5 $7 $9 (build-src 9))]
       #;[(for O_PAREN ForInit SEMI_COLON SEMI_COLON ForUpdate C_PAREN Statement)
	(make-for $3 
                      (make-literal 'boolean (build-src 4 5) #t) 
		      $6 
                      $8 
                      (build-src 8))])
	
      
      (ForStatementNoShortIf
       [(for O_PAREN ForInit SEMI_COLON Expression SEMI_COLON ForUpdate C_PAREN Block #;StatementNoShortIf)
	(make-for $3 $5 $7 $9 (build-src 9))]
       [(for O_PAREN ForInit SEMI_COLON SEMI_COLON ForUpdate C_PAREN StatementNoShortIf)
      	(make-for $3 (make-literal 'boolean #t (build-src 4 5)) 
		      $6 $8 (build-src 8))])
      (ForInit
       [() null]
       [(StatementExpressionList) (reverse $1)]
       [(LocalVariableDeclaration) (reverse $1)])
      
      (ForUpdate
       [() null]
       [(StatementExpressionList) (reverse $1)])
      
      (StatementExpressionList
       [(StatementExpression) (list $1)]
       [(Assignment) (list $1)]
       [(StatementExpressionList COMMA StatementExpression) (cons $3 $1)])
      
      (BreakStatement
       [(break SEMI_COLON) (make-break #f (build-src 2))])
      
      (ContinueStatement
       [(continue SEMI_COLON) (make-continue #f (build-src 2))])
       
      (ReturnStatement
       [(return Expression SEMI_COLON) (make-return $2 #f #f (build-src 3))]
       [(return SEMI_COLON) (make-return #f #f #f (build-src 2))])
      
      ;; 19.12
      
      (Primary
       [(PrimaryNoNewArray) $1]
       [(ArrayCreationExpression) $1])
      
      (PrimaryNoNewArray
       [(Literal) $1]
       [(this) (make-special-name #f (build-src 1) "this")]
       [(O_PAREN Expression C_PAREN) $2]
       [(ClassInstanceCreationExpression) $1]
       [(FieldAccess) $1]
       [(MethodInvocation) $1]
       [(ArrayAccess) $1])
       
      (ClassInstanceCreationExpression
       [(new ClassOrInterfaceType O_PAREN ArgumentList C_PAREN)
	(make-class-alloc #f (build-src 5) $2 (reverse $4) #f #f #f)]
       [(new ClassOrInterfaceType O_PAREN C_PAREN) 
	(make-class-alloc #f (build-src 4) $2 null #f #f #f)])
      
      (ArgumentList
       [(Expression) (list $1)]
       [(ArgumentList COMMA Expression) (cons $3 $1)])
      
      (ArrayCreationExpression
       [(new PrimitiveType DimExprs Dims) (make-array-alloc #f (build-src 4) $2 (reverse $3) $4)]
       [(new PrimitiveType DimExprs) (make-array-alloc #f (build-src 3) $2 (reverse $3) 0)]
       [(new ClassOrInterfaceType DimExprs Dims)
        (make-array-alloc #f (build-src 4) (make-type-spec $2 0 (build-src 2 2)) (reverse $3) $4)]
       [(new ClassOrInterfaceType DimExprs)
        (make-array-alloc #f (build-src 3) (make-type-spec $2 0 (build-src 2 2)) (reverse $3) 0)]
       ;; 1.1
       #;[(new PrimitiveType Dims ArrayInitializer) 
        (begin (display $2)
               (error 'unimplemented-1.1))]
       ;; 1.1
       #;[(new ClassOrInterfaceType Dims ArrayInitializer) (error 'unimplemented-1.1)])
      
      (DimExprs
       [(DimExpr) (list $1)]
       [(DimExprs DimExpr) (cons $2 $1)])

      (DimExpr
       [(O_BRACKET Expression C_BRACKET) $2])
      
      (Dims
       [(O_BRACKET C_BRACKET) 1]
       [(Dims O_BRACKET C_BRACKET) (add1 $1)])
      
      (FieldAccess
       [(Primary PERIOD IDENTIFIER) 
        (make-access #f (build-src 3) (make-field-access $1 
                                                                 (make-id $3 (build-src 3 3)) #f))]
       [(super PERIOD IDENTIFIER) 
        (make-access #f (build-src 3)
                         (make-field-access (make-special-name #f (build-src 1)
                                                                       "super")
                                                (make-id $3 (build-src 3 3))
                                                #f))])
      
      (MethodInvocation
       [(Name O_PAREN ArgumentList C_PAREN) (build-name-call $1 (reverse $3) (build-src 4))]
       [(Name O_PAREN C_PAREN) (build-name-call $1 null (build-src 3))]
       [(Primary PERIOD IDENTIFIER O_PAREN ArgumentList C_PAREN)
        (make-call #f (build-src 6) $1 (make-id $3 (build-src 3 3)) (reverse $5) #f)]
       [(Primary PERIOD IDENTIFIER O_PAREN C_PAREN)
        (make-call #f (build-src 5) $1 (make-id $3 (build-src 3 3)) null #f)]
       [(super PERIOD IDENTIFIER O_PAREN ArgumentList C_PAREN)
        (make-call #f (build-src 6) 
                       (make-special-name #f (build-src 1) "super") 
                       (make-id $3 (build-src 3 3)) (reverse $5) #f)]
       [(super PERIOD IDENTIFIER O_PAREN C_PAREN)
        (make-call #f (build-src 5) 
                       (make-special-name #f (build-src 1) "super") 
                       (make-id $3 (build-src 3 3)) null #f)])
      
      (ArrayAccess
       [(Name O_BRACKET Expression C_BRACKET)
        (make-array-access #f (build-src 4) (name->access $1) $3)]
       [(PrimaryNoNewArray O_BRACKET Expression C_BRACKET)
	(make-array-access #f (build-src 4) $1 $3)])
      
      (PostfixExpression
       [(Primary) $1]
       [(Name) (name->access $1)]
       [(PostIncrementExpression) $1]
       [(PostDecrementExpression) $1])
      
      (PostIncrementExpression
       [(PostfixExpression ++) (make-post-expr #f (build-src 2) $1 '++ (build-src 2 2))])
      
      (PostDecrementExpression
       [(PostfixExpression --) (make-post-expr #f (build-src 2) $1 '-- (build-src 2 2))])
      
      (UnaryExpression
       [(PreIncrementExpression) $1]
       [(PreDecrementExpression) $1]
       [(+ UnaryExpression) (make-unary #f (build-src 2) '+ $2 (build-src 1))]
       [(- UnaryExpression) (make-unary #f (build-src 2) '- $2 (build-src 1))]
       [(UnaryExpressionNotPlusMinus) $1])
      
      (PreIncrementExpression
       [(++ UnaryExpression) (make-pre-expr #f (build-src 2) '++ $2 (build-src 1))])

      (PreDecrementExpression
       [(-- UnaryExpression) (make-pre-expr #f (build-src 2) '-- $2 (build-src 1))])
      
      (UnaryExpressionNotPlusMinus
       [(PostfixExpression) $1]
       [(~ UnaryExpression) (make-unary #f (build-src 2) '~ $2 (build-src 1))]
       [(! UnaryExpression) (make-unary #f (build-src 2) '! $2 (build-src 1))]
       [(CastExpression) $1])
      
      (CastExpression
       [(O_PAREN PrimitiveType Dims C_PAREN UnaryExpression)
	(make-cast #f (build-src 5) 
		       (make-type-spec (type-spec-name $2)
                                           $3
                                           (build-src 2 3))
		       $5)]
       [(O_PAREN PrimitiveType C_PAREN UnaryExpression)
	(make-cast #f (build-src 4) $2 $4)]
       [(O_PAREN Expression C_PAREN UnaryExpressionNotPlusMinus)
        (if (access? $2)
            (make-cast #f (build-src 4) 
                           (make-type-spec (access->name $2) 0 (build-src 2 2)) $4)
            (raise-read-error "An operator is needed to combine these expressions."
                              (file-path)
                              (position-line $1-start-pos)
                              (position-col $1-start-pos)
                              (+ (position-offset $1-start-pos) (interactions-offset))
                              (- (position-offset $4-end-pos)
                                 (position-offset $1-start-pos))))]
       ;; GJ - Not sure if this is in spec or not.
       ;;[(O_PAREN Name < ReferenceTypeList1 C_PAREN UnaryExpressionNotPlusMinus) #t]
       [(O_PAREN Name Dims C_PAREN UnaryExpressionNotPlusMinus)
	(make-cast #f (build-src 4)
		       (make-type-spec $2 $3 (build-src 2 3))
		       $5)])

      (MultiplicativeExpression
       [(UnaryExpression) $1]
       [(MultiplicativeExpression * UnaryExpression)
        (make-bin-op #f (build-src 3) '* $1 $3 (build-src 2 2))]
       [(MultiplicativeExpression / UnaryExpression)
	(make-bin-op #f (build-src 3) '/ $1 $3 (build-src 2 2))]
       [(MultiplicativeExpression % UnaryExpression)
	(make-bin-op #f (build-src 3) '% $1 $3 (build-src 2 2))])
      
      (AdditiveExpression
       [(MultiplicativeExpression) $1]
       [(AdditiveExpression + MultiplicativeExpression)
	(make-bin-op #f (build-src 3) '+ $1 $3 (build-src 2 2))]
       [(AdditiveExpression - MultiplicativeExpression)
	(make-bin-op #f (build-src 3) '- $1 $3 (build-src 2 2))])
      
      (ShiftExpression
       [(AdditiveExpression) $1]
       [(ShiftExpression << AdditiveExpression)
	(make-bin-op #f (build-src 3) '<< $1 $3 (build-src 2 2))]
       [(ShiftExpression >> AdditiveExpression)
	(make-bin-op #f (build-src 3) '>> $1 $3 (build-src 2 2))]	
       [(ShiftExpression >>> AdditiveExpression)
	(make-bin-op #f (build-src 3) '>>> $1 $3 (build-src 2 2))])
      

      (RelationalExpression
       [(ShiftExpression) $1]
       ;; GJ - changed to remove shift/reduce conflict
       [(ShiftExpression < ShiftExpression)
        (make-bin-op #f (build-src 3) '< $1 $3 (build-src 2 2))]		
       [(RelationalExpression > ShiftExpression)
	(make-bin-op #f (build-src 3) '> $1 $3 (build-src 2 2))]	
       [(RelationalExpression <= ShiftExpression)
	(make-bin-op #f (build-src 3) '<= $1 $3 (build-src 2 2))]	
       [(RelationalExpression >= ShiftExpression)
	(make-bin-op #f (build-src 3) '>= $1 $3 (build-src 2 2))]	
       [(RelationalExpression instanceof ReferenceType)
	(make-instanceof #f (build-src 3) $1 $3 (build-src 2 2))])
      

      (EqualityExpression
       [(RelationalExpression) $1]
       [(EqualityExpression == RelationalExpression)
	(make-bin-op #f (build-src 3) '== $1 $3 (build-src 2 2))]	
       [(EqualityExpression != RelationalExpression)
	(make-bin-op #f (build-src 3) '!= $1 $3 (build-src 2 2))])
      
      (AndExpression
       [(EqualityExpression) $1]
       [(AndExpression & EqualityExpression)
	(make-bin-op #f (build-src 3) '& $1 $3 (build-src 2 2))])
	
      
      (ExclusiveOrExpression
       [(AndExpression) $1]
       [(ExclusiveOrExpression ^ AndExpression)
	(make-bin-op #f (build-src 3) '^ $1 $3 (build-src 2 2))])

      
      (InclusiveOrExpression
       [(ExclusiveOrExpression) $1]
       [(InclusiveOrExpression PIPE ExclusiveOrExpression)
	(make-bin-op #f (build-src 3) 'or $1 $3 (build-src 2 2))])
      
      (ConditionalAndExpression
       [(InclusiveOrExpression) $1]
       [(ConditionalAndExpression && InclusiveOrExpression)
	(make-bin-op #f (build-src 3) '&& $1 $3 (build-src 2 2))])
      
      (ConditionalOrExpression
       [(ConditionalAndExpression) $1]
       [(ConditionalOrExpression OR ConditionalAndExpression)
	(make-bin-op #f (build-src 3) 'oror $1 $3 (build-src 2 2))])
      
      (ConditionalExpression
       [(ConditionalOrExpression) $1]
       [(ConditionalOrExpression ? Expression : ConditionalExpression)
	(make-cond-expression #f (build-src 5) $1 $3 $5 (build-src 2 2))])
      
      (CheckExpression
       [(ConditionalExpression) $1]
       [(check ConditionalExpression expect ConditionalExpression) 
        (make-check-expect #f (build-src 4) $2 $4 #f (build-src 2 4))]
       [(check ConditionalExpression expect ConditionalExpression within ConditionalExpression) 
        (make-check-expect #f (build-src 6) $2 $4 $6 (build-src 2 4))])
      
      (AssignmentExpression
       [#;(ConditionalExpression)(CheckExpression) $1])
      
      (Assignment
       [(LeftHandSide AssignmentOperator AssignmentExpression)
	(make-assignment #f (build-src 3) $1 $2 $3 (build-src 2 2))])
      
      (LeftHandSide
       [(Name) (name->access $1)]
       [(FieldAccess) $1]
       [(ArrayAccess) $1])
      
      (AssignmentOperator
       [(=) '=]
       [(*=) '*=]
       [(/=) '/=]
       [(%=) '%=]
       [(+=) '+=]
       [(-=) '-=]
       [(<<=) '<<=]
       [(>>=) '>>=]
       [(>>>=) '>>>=]
       [(&=) '&=]
       [(^=) '^=]
       [(OREQUAL) 'or=])
      
      (Expression
       [(AssignmentExpression) $1])
      
      (ConstantExpression
       [(Expression) $1]))))
  
  (define parse-advanced (car parsers))
  (define parse-advanced-interactions (cadr parsers))
  (define parse-advanced-expression (caddr parsers))
  (define parse-advanced-type (cadddr parsers))
  )
