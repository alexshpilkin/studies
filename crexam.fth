\ Conditions and restarts --- Example

S" conres.fth" INCLUDED

: I/O?-DEVICE ( i/o? -- i/o? dev# )   OVER ;
: DISPLAY-I/O?
  ." input/output error on device " I/O?-DEVICE . ;
? CLONE I/O? ( dev# -- i/o? )   ? >UNHANDLED @ ,
  ' DISPLAY-I/O? ,

VARIABLE BUFFER

: (READ-BYTE) ( simulate an error and garbage data )
  42 BUFFER !   123 I/O? SIGNAL ;

HERE ," IGNORE?" DUP HERE SWAP -
: DESCRIBE-IGNORE?   ." Ignore the error and proceed" ;
RESTART? CLONE IGNORE?   RESTART? >UNHANDLED @ ,
  RESTART? >DISPLAY @ , ( c-addr len ) , , ' DESCRIBE-IGNORE? ,

HERE ," RETRY?" DUP HERE SWAP -
: DESCRIBE-RETRY?   ." Retry the operation" ;
RESTART? CLONE RETRY?   RESTART? >UNHANDLED @ ,
  RESTART? >DISPLAY @ , ( c-addr len ) , , ' DESCRIBE-RETRY? ,

: READ-BYTE
  BEGIN
    MARK
    [: MARK ['] (READ-BYTE) IGNORE? RESTART TRIM ;]
    RETRY? RESTART
  WHILE
    TRIM
  REPEAT R> DROP ;

: APPLICATION   READ-BYTE ." Read byte: " BUFFER @ . CR ;

HERE ," ABORT?" DUP HERE SWAP -
: DESCRIBE-ABORT?   ." Stop and return to shell" ;
RESTART? CLONE ABORT?   RESTART? >UNHANDLED @ ,
  RESTART? >DISPLAY @ , ( c-addr len ) , , ' DESCRIBE-ABORT? ,

: SHELL
  MARK
  ['] APPLICATION ABORT? RESTART IF ." Aborted " CR THEN
  TRIM ;

: MORE-RESPONSES   0 @F ['] DEFAULT-RESPONSE <> ;
: NEXT-RESPONSE   1 @F ;
: RESTART-RESPONSE   DUP 0 @F ['] (HANDLE) =   ANDIF DUP 2 @F
  RESTART? EXTENDS THEN ;
: RESTART.   DUP >NAME 2@ TYPE ."  -- " DESCRIBE DROP ;
: LIST-RESTARTS   ." Restarts:" CR   RESPONSE @ BEGIN
  RESTART-RESPONSE IF   DUP 2 @F   2 SPACES RESTART. CR   THEN
  DUP MORE-RESPONSES WHILE   NEXT-RESPONSE REPEAT DROP ;

: SYSTEM
  ['] SHELL ? [:
    ( hf ) DROP   ." Signalled " DISPLAY CR   LIST-RESTARTS
    PAD DUP 84 ACCEPT CR   EVALUATE SIGNAL
  ;] HANDLE ;

CR SYSTEM
