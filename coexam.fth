\ Conditions and restarts --- Example

S" condit.fth" INCLUDED

: I/O?-DEVICE ( i/o? -- i/o? dev# )   OVER ;
: PRINT-I/O?
  ." input/output error on device " I/O?-DEVICE . ;
? CLONE I/O? ( dev# -- i/o? )   ? >UNHANDLED @ , ' PRINT-I/O? ,

VARIABLE BUFFER

: (READ-BYTE) ( simulate an error and garbage data )
  42 BUFFER !   123 I/O? SIGNAL ;

: PRINT-IGNORE
  ." IGNORE  Ignore the error and proceed" ;
TOP CLONE IGNORE   0 , ' PRINT-IGNORE ,

: PRINT-RETRY
  ." RETRY   Retry the operation and hope the error disappears" ;
TOP CLONE RETRY   0 , ' PRINT-RETRY ,

: READ-BYTE
  BEGIN
    MARK
    [: MARK ['] (READ-BYTE) IGNORE PROPOSE TRIM ;]
    RETRY PROPOSE
  WHILE
    TRIM
  REPEAT F> DROP ;

: APPLICATION   READ-BYTE ." Read byte: " BUFFER @ . CR ;

: PRINT-ABORT
  ." ABORT   Stop and return to shell" ;
TOP CLONE ABORT   0 , ' PRINT-ABORT ,

: SHELL
  MARK
  ['] APPLICATION ABORT PROPOSE IF ." Aborted " THEN CR
  TRIM ;

: SYSTEM
  ['] SHELL [:
    ( hf ) DROP
    ." Signalled " PRINT CR   ." Restarts:" CR   OFFERS @ BEGIN
    DUP FP0 <> WHILE   DUP 1 @F   2 SPACES PRINT CR   DROP
    0 @F REPEAT DROP   PAD DUP 84 ACCEPT CR   EVALUATE INVOKE
  ;] ? HANDLE ;

CR SYSTEM
