\ Conditions and restarts

\ For symmetry with CELL+
: CELL-   [ 1 CELLS ] LITERAL - ;
\ From folklore
: +CONSTANT   CREATE , DOES> @ + ;
\ From folklore
: ,"   [CHAR] " PARSE   HERE   OVER ALLOT   SWAP CMOVE ;
\ From Wil Baden's TOOLBELT 2002
: ANDIF   POSTPONE DUP POSTPONE IF POSTPONE DROP ; IMMEDIATE
\ For backtraces in Gforth
: NOTHROW   ['] FALSE CATCH 2DROP ;

\ Frame stack

CREATE FSTACK   32 CELLS ALLOT   FSTACK CELL- CONSTANT FP0
VARIABLE FP   FP0 FP !
: FP@ ( -- fp )   FP @ ;
: >F ( x -- )   FP @   CELL+ DUP FP !   ! ;
: F> ( -- x )   FP @   DUP CELL- FP !   @ ;
: @F ( fp n -- x )   CELLS - @ ;

\ Stack-preserving THROW and CATCH

VARIABLE CATCHDEPTH   VARIABLE STASHDEPTH
CREATE STASH   32 CELLS ALLOT

: THROW ( -* )
  DEPTH CATCHDEPTH @ - DUP STASHDEPTH !   >R STASH BEGIN
  R@ 0 > WHILE   TUCK ! CELL+   R> 1- >R REPEAT   DROP R> DROP
  1 THROW ;

: CATCH ( ... xt -- ... f )
  CATCHDEPTH @ >R   DEPTH 1- CATCHDEPTH !   FP @ >R   CATCH
  R> FP !   R> CATCHDEPTH !   ( ... error ) DUP 1 = IF DROP
    STASHDEPTH @   DUP >R CELLS STASH + BEGIN   R@ 0 > WHILE
    CELL- DUP @ SWAP   R> 1- >R REPEAT DROP   BEGIN
    R@ 0 < WHILE   DROP   R> 1+ >R REPEAT R> DROP   TRUE
  ELSE   DUP IF THROW THEN   THEN ;

: MARK   POSTPONE DEPTH POSTPONE >R ; IMMEDIATE
: (TRIM)   >R   BEGIN DEPTH R@ U> WHILE DROP REPEAT   R> DROP ;
: TRIM   POSTPONE R> POSTPONE (TRIM) ; IMMEDIATE

\ SIGNAL, RESPOND, and PASS

VARIABLE RESPONSE

: SIGNAL   RESPONSE @    DUP 0 @F EXECUTE ;

: RESPOND ( ... xt response-xt -- ... )
  RESPONSE @ >F   >F   FP@ RESPONSE !   CATCH ( ... f )
  F> DROP   F> RESPONSE !   IF THROW THEN   NOTHROW ;

: (PASS)   1 @F   DUP 0 @F EXECUTE ;
: PASS ( rf -* )   POSTPONE (PASS) POSTPONE EXIT ; IMMEDIATE

\ ESCAPE and RESUME

: ESCAPE ( tag -* )   POSTPONE THROW ; IMMEDIATE

: RESUME ( ... xt -- ... f )
  FP@ SWAP   0 >F   CATCH ( ... 0 | tag -1 )   F> DROP
  DUP ANDIF OVER FP@ <> THEN   IF DROP THROW THEN   NOTHROW
  DUP IF NIP THEN ;
\ the 0 ensures different RESUMEs have different tags

\ Class system

HERE CELL+ DUP , 1 CELLS ,   CONSTANT TOP

: CLONE ( c "name" -- )   DUP >R   CREATE HERE >R   DUP @
  TUCK - SWAP   [ 2 CELLS ] LITERAL + DUP ,   R> + ,   BEGIN
  DUP R@ < WHILE   DUP @ ,   CELL+ REPEAT   @ CELL+ , R> DROP
  DOES>   DUP @ + ;

: EXTENDS ( c1 c2 -- )   OVER @ OVER @ MIN   ROT SWAP - @   = ;

: METHOD ( xt "name" -- ) ( ... c -- ... c )
  CREATE ,   DOES>   >R DUP R> @ EXECUTE @ EXECUTE ;

\ HANDLE

: (HANDLE) ( ... c fp -- ... )   2DUP 2 @F EXTENDS IF
  DUP 3 @F EXECUTE   ELSE   PASS   THEN ;
: HANDLE ( ... xt c handler-xt -- ... )   >F >F
  ['] (HANDLE) RESPOND   F> DROP F> DROP ;

1 CELLS +CONSTANT >UNHANDLED   ' >UNHANDLED METHOD UNHANDLED
2 CELLS +CONSTANT >PRINT   ' >PRINT METHOD PRINT

: DEFAULT-RESPONSE   ( с rf ) DROP UNHANDLED ;
' DEFAULT-RESPONSE >F   FP@ RESPONSE !

: UNHANDLED-?   ." Unhandled " PRINT ABORT ;
: PRINT-?   ." unspecified error " ;
TOP CLONE ?   ' UNHANDLED-? , ' PRINT-? ,

\ UNWIND and RESTART

: ((UNWIND)) ( ... c hf -* )   4 @F ESCAPE ;
: (UNWIND) ( ... xt c tag -- ... )
  >F   ['] ((UNWIND)) HANDLE   F> DROP ;
: UNWIND ( ... xt c -- ... f )   ['] (UNWIND) RESUME ;

VARIABLE RESTARTS   FP0 RESTARTS !

: RESTART ( ... xt c -- ... f )
  DUP >F   RESTARTS @ >F   FP@ RESTARTS !   UNWIND
  F> RESTARTS !   F> DROP ;

3 CELLS +CONSTANT >NAME
5 CELLS +CONSTANT >DESCRIBE   ' >DESCRIBE METHOD DESCRIBE

: PRINT-RESTART?   ." error: no restart "   DUP >NAME 2@ TYPE ;
HERE ," RESTART?" DUP HERE SWAP -
: DESCRIBE-RESTART?   ." Unknown restart" ;
? CLONE RESTART? ( ... c -- restart? )   ? >UNHANDLED @ ,
  ' PRINT-RESTART? , ( c-addr len ) , , ' DESCRIBE-RESTART? ,
