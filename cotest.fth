\ Tests for conditions

VARIABLE PREVIOUS-DEPTH   VARIABLE TEST-DEPTH
CREATE TEST-STACK   16 CELLS ALLOT
: T{   DEPTH PREVIOUS-DEPTH ! ;
: ->   DEPTH PREVIOUS-DEPTH @ -   DUP TEST-DEPTH !
  CELLS TEST-STACK TUCK + >R   BEGIN   DUP R@ U< WHILE   TUCK !
  CELL+ REPEAT   DROP R> DROP ;
: }T   DEPTH PREVIOUS-DEPTH @ -   DUP TEST-DEPTH @ <>
  ABORT" Stack depth differs"   CELLS TEST-STACK TUCK + >R
  BEGIN   DUP R@ U< WHILE   TUCK @ <>
  ABORT" Stack contents differ"   CELL+ REPEAT   DROP R> DROP ;

\ THROW and CATCH

: TEST-NOTHROW   ;
: TEST-NOCATCH   ['] TEST-NOTHROW CATCH ;
T{ TEST-NOCATCH -> 0 }T

: TEST-UNDERTHROW   >F THROW ;
: TEST-UNDERCATCH   1 2 >F 3   ['] TEST-UNDERTHROW CATCH AND   F> ;
T{ TEST-UNDERCATCH -> 1 2 }T

: TEST-OVERTHROW   4 5 THROW ;
: TEST-OVERCATCH   3   ['] TEST-OVERTHROW CATCH AND ;
T{ TEST-OVERCATCH -> 3 4 5 }T

: TEST-NESTTHROW   TEST-NOCATCH TEST-UNDERCATCH
  TEST-OVERCATCH THROW ;
: TEST-NESTCATCH   -2 -1 ['] TEST-NESTTHROW CATCH AND ;
T{ TEST-NESTCATCH -> -2 -1 0 1 2 3 4 5 }T

\ SIGNAL, RESPOND, and PASS

: TEST-RESPOND-S   2 SIGNAL ;
: TEST-RESPOND-R   DROP 1 - ;
: TEST-RESPOND  ['] TEST-RESPOND-S ['] TEST-RESPOND-R RESPOND
  RESPONSE @ FP0 CELL+ = AND ;
T{ TEST-RESPOND -> 1 }T

: TEST-PASS-S   1 SIGNAL ;
: TEST-PASS-R   3 SWAP PASS ;
: TEST-PASS-T   ['] TEST-PASS-S ['] TEST-PASS-R   RESPOND ;
: TEST-PASS   ['] TEST-PASS-T ['] TEST-RESPOND-R RESPOND
  RESPONSE @ FP0 CELL+ = AND ;
T{ TEST-PASS -> 1 2 }T

\ OFFER and AGREE

: TEST-NOAGREE-A   DROP ;
: TEST-NOAGREE   ['] TEST-NOAGREE-A OFFER ;
T{ TEST-NOAGREE -> 0 }T

: TEST-INNERAGREE-A   1 SWAP AGREE ;
: TEST-INNERAGREE   ['] TEST-INNERAGREE-A OFFER AND ;
T{ TEST-INNERAGREE -> 1 }T

: TEST-OUTERAGREE-A   DROP 2 SWAP AGREE ;
: TEST-OUTERAGREE-B   ['] TEST-OUTERAGREE-A OFFER ;
: TEST-OUTERAGREE   ['] TEST-NOAGREE OFFER OR NIP
  ['] TEST-INNERAGREE OFFER OR NIP   ['] TEST-OUTERAGREE-B OFFER AND
  OFFERS @ FP0 = AND ;
T{ TEST-OUTERAGREE -> 0 1 2 }T

\ Class system

: TEST-TOP   TOP   DUP @ SWAP   CELL- DUP @ SWAP   DROP ;
T{ TEST-TOP -> 1 CELLS TOP }T

: >FROB   CELL+ ;
TOP CLONE FOO   2 ,
: TEST-FOO   FOO   DUP @ SWAP   CELL- DUP @ SWAP
  CELL- DUP @ SWAP   DROP   FOO >FROB @ ;
T{ TEST-FOO -> 2 CELLS TOP FOO 2 }T

FOO CLONE BAR   57 ,
: TEST-BAR   BAR   DUP @ SWAP   CELL- DUP @ SWAP
  CELL- DUP @ SWAP   CELL- DUP @ SWAP   DROP   BAR >FROB @ ;
T{ TEST-BAR -> 3 CELLS TOP FOO BAR 57 }T

BAR CLONE BAZ   179 ,
: TEST-BAZ   BAZ   DUP @ SWAP   CELL- DUP @ SWAP
  CELL- DUP @ SWAP   CELL- DUP @ SWAP   CELL- DUP @ SWAP
  DROP   BAZ >FROB @ ;
T{ TEST-BAZ -> 4 CELLS TOP FOO BAR BAZ 179 }T

: TEST-EXTENDS   FOO TOP EXTENDS   BAZ FOO EXTENDS
  BAR BAZ EXTENDS ;
T{ TEST-EXTENDS -> TRUE TRUE FALSE }T

\ Conditions

? CLONE FOO?   ? >UNHANDLED @ , ? >PRINT @ ,

: TEST-HANDLE-S   1 FOO? SIGNAL ;
: TEST-HANDLE-H   ( c rf ) 2DROP 2 ;
: TEST-HANDLE   0 ['] TEST-HANDLE-S ['] TEST-HANDLE-H FOO?
  HANDLE ;
T{ TEST-HANDLE -> 0 1 2 }T

: UNHANDLED-BAR?   ( c ) DROP   1 = ;
? CLONE BAR?   ' UNHANDLED-BAR? , ? >PRINT @ ,

: TEST-NOHANDLE-S   1 BAR? SIGNAL ;
: TEST-NOHANDLE   0 ['] TEST-NOHANDLE-S ['] TEST-HANDLE-H FOO?
  HANDLE ;
T{ TEST-NOHANDLE -> 0 -1 }T

: TEST-NESTHANDLE   ['] TEST-NOHANDLE ['] TEST-HANDLE-H BAR?
  HANDLE ;
T{ TEST-NESTHANDLE -> 0 1 2 }T

\ Restarts

TOP CLONE QUUX   0 , 0 ,

: TEST-INVOKE-P   1 QUUX INVOKE ;
: TEST-INVOKE   0 ['] TEST-INVOKE-P QUUX PROPOSE IF
  QUUX = 2 AND   THEN ;
T{ TEST-INVOKE -> 0 1 2 }T
