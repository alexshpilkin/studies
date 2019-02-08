\ Conditions

\ For backtraces in Gforth
: NOTHROW   ['] FALSE CATCH 2DROP ;

\ Frame stack

CREATE FP0   32 CELLS ALLOT   VARIABLE FP   FP0 FP !
: FP@ ( -- fa )   FP @ ;
: >F ( x -- )   FP @   DUP CELL+ FP !       ! ;
: F> ( -- x )   FP @   1 CELLS - DUP FP !   @ ;
: @F ( fa n -- x )   1+ CELLS - @ ;

\ Stack-preserving THROW and CATCH

VARIABLE CATCHDEPTH   VARIABLE STASHDEPTH
CREATE STASH   32 CELLS ALLOT

: CATCH ( ... xt -- ... f )
  CATCHDEPTH @ >R   DEPTH 1- CATCHDEPTH !   FP @ >R   CATCH
  R> FP !   R> CATCHDEPTH !   ( ... error ) DUP 1 = IF DROP
    STASHDEPTH @   DUP >R CELLS STASH + BEGIN   R@ 0 > WHILE
    1 CELLS - DUP @ SWAP   R> 1- >R REPEAT DROP   BEGIN
    R@ 0 < WHILE   DROP   R> 1+ >R REPEAT RDROP   TRUE
  ELSE   DUP IF THROW THEN   THEN ;

: THROW ( ... -* )   DEPTH CATCHDEPTH @ - DUP STASHDEPTH !
  >R STASH BEGIN   R@ 0 > WHILE   TUCK ! CELL+   R> 1- >R REPEAT
  RDROP   1 THROW ;

\ SIGNAL, HANDLE, and DECLINE

VARIABLE HANDLER   FP0 HANDLER !

: SIGNAL   HANDLER @    DUP 0 @F EXECUTE ;

: HANDLE ( ... xt handler-xt -- ... )
  HANDLER @ >F   >F   FP@ HANDLER !   CATCH ( ... f )
  F> DROP   F> HANDLER !   IF THROW THEN   NOTHROW ;

: DECLINE ( fa -* )   1 @F   DUP 0 @F EXECUTE ;

\ Class system

CREATE TOP   0 ,
: CLASS ( c "name" -- )   CREATE HERE SWAP   DUP @ CELL+ DUP ,
  OVER + >R   CELL+ BEGIN   DUP R@ < WHILE   DUP @ ,   CELL+
  REPEAT DROP RDROP   , ;
: EXTENDS ( c1 c2 -- )   OVER @ OVER @ MIN   ROT + @   = ;
