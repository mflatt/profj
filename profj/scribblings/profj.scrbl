#lang scribble/manual

@title{ProfessorJ: Java in Racket}

ProfessorJ is a plug-in for DrRacket that implements variants of Java,
especially for teaching purposes. After installing ProfessorJ (and
restarting DrRacket, if necessary), use the @onscreen{Choose Language...}
dialog in DrRacket to select one of the languages. For information on
the supported languages, see @other-doc['(lib
"profj/scribblings/htdc.scrbl")].

ProfessorJ's languages are also available for use with @hash-lang[].
For example,

@codeblock|{
  #lang profj/full

  class Example {
    static String result = null;
    public static void Main(String[] args) {
      result = "Hi";
    }
  }
}|

is a program in ProfessorJ's Full language. The Racket view of this
module is that it has an @racket[Example] submodule that exports an
@racket[Example] class, an @racket[Example-main-java.lang.String1]
function, and an @racket[Example-result~f] variable, among other
bindings.


@section{ProfessorJ Languages for Racket Modules}

@defmodule[profj/beginner #:lang #:no-declare]
@defmodule[profj/intermediate #:lang #:no-declare]
@defmodule[profj/intermediate+access #:lang #:no-declare]
@defmodule[profj/advanced #:lang #:no-declare]
@defmodule[profj/full #:lang #:no-declare]
@defmodule[profj/dynamic #:lang #:no-declare]



@section{Class Search Paths}

When ProfessorJ compiles a program that includes a reference to a
class @racket[_C], it searches for the class's definition with the
following sequence:

@itemlist[

 @item{as defined in the current source file;}

 @item{as described by a file @filepath{compiled/@racket[_C].jinfo}
       and implemented by @filepath{@racket[_C].rkt} or
       @filepath{compiled/@racket[_C]_rkt.zo} (where @filepath{rkt}
       can be @filepath{ss}, instead);}

 @item{as exported by @filepath{@racket[_C].ss} or @filepath{@racket[_C].scm},
       but only as referenced from the ProfessorJ Dynamic language;}

 @item{as described by a @racket[jinfo] submodule of @filepath{@racket[_C].rkt},
       which corresponds to a @racket[@#,hash-lang[] profj/...] module.}

 @item{as implemented in @filepath{@racket[_C].bjava},
       @filepath{@racket[_C].ijava}, @filepath{@racket[_C].iajava},
       @filepath{@racket[_C].ajava}, @filepath{@racket[_C].ajava}, or
       @filepath{@racket[_C].djava}, where the file suffix determines
       the ProfessorJ language variant---but in this case, the
       information is sufficient only to @racket[read] the
       referencing code, not expand or compile it.}

]

A ProfessorJ source file as in the last case normally must be compiled
in advance to @filepath{compiled/@racket[_C].jinfo} and
@filepath{compiled/@racket[_C]_rkt.zo} files.



