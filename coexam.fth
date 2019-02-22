\ Conditions and restarts --- Example

S" condit.fth" INCLUDED

: I/O?-DEVICE ( i/o? -- i/o? dev# )   OVER ;
: PRINT-I/O?
  ." input/output error on device " I/O?-DEVICE . ;
? CLONE I/O? ( dev# -- i/o? )   ? >UNHANDLED @ , ' PRINT-I/O? ,

VARIABLE BUFFER

: (READ-BYTE) ( simulate an error and garbage data )
  42 BUFFER !   123 I/O? SIGNAL ;

HERE ," IGNORE?" DUP HERE SWAP -
: DESCRIBE-IGNORE?   ." Ignore the error and proceed" ;
RESTART? CLONE IGNORE?   RESTART? >UNHANDLED @ ,
  RESTART? >PRINT @ , ( c-addr len ) , , ' DESCRIBE-IGNORE? ,

HERE ," RETRY?" DUP HERE SWAP -
: DESCRIBE-RETRY?   ." Retry the operation" ;
RESTART? CLONE RETRY?   RESTART? >UNHANDLED @ ,
  RESTART? >PRINT @ , ( c-addr len ) , , ' DESCRIBE-RETRY? ,

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
TOP CLONE ABORT?   RESTART? >UNHANDLED @ , RESTART? >PRINT @ ,
  ( c-addr len ) , , ' DESCRIBE-ABORT? ,

: SHELL
  MARK
  ['] APPLICATION ABORT? RESTART IF ." Aborted " CR THEN
  TRIM ;

: SYSTEM
  ['] SHELL ? [:
    ( hf ) DROP
    ." Signalled " PRINT CR   ." Restarts:" CR   RESTARTS @
    BEGIN   DUP FP0 <> WHILE   DUP 1 @F   2 SPACES
    DUP >NAME 2@ TYPE ."  -- " DESCRIBE CR   DROP
    0 @F REPEAT DROP   PAD DUP 84 ACCEPT CR   EVALUATE SIGNAL
  ;] HANDLE ;

CR SYSTEM
