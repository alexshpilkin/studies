\ Conditions

\ For symmetry with CELL+
: CELL-   [ 1 CELLS ] LITERAL - ;
\ From Wil Baden's TOOLBELT 2002
: ANDIF   POSTPONE DUP POSTPONE IF POSTPONE DROP ; IMMEDIATE
\ For backtraces in Gforth
: NOTHROW   ['] FALSE CATCH 2DROP ;

\ Frame stack

CREATE FP0   32 CELLS ALLOT   VARIABLE FP   FP0 FP !
: FP@ ( -- fp )   FP @ ;
: >F ( x -- )   FP @   DUP CELL+ FP !   ! ;
: F> ( -- x )   FP @   CELL- DUP FP !   @ ;
: @F ( fp n -- x )   1+ CELLS - @ ;

\ Stack-preserving THROW and CATCH

VARIABLE CATCHDEPTH   VARIABLE STASHDEPTH
CREATE STASH   32 CELLS ALLOT

: THROW ( -* )
  DEPTH CATCHDEPTH @ - DUP STASHDEPTH !   >R STASH BEGIN
  R@ 0 > WHILE   TUCK ! CELL+   R> 1- >R REPEAT  RDROP
  1 THROW ;

: CATCH ( ... xt -- ... f )
  CATCHDEPTH @ >R   DEPTH 1- CATCHDEPTH !   FP @ >R   CATCH
  R> FP !   R> CATCHDEPTH !   ( ... error ) DUP 1 = IF DROP
    STASHDEPTH @   DUP >R CELLS STASH + BEGIN   R@ 0 > WHILE
    CELL- DUP @ SWAP   R> 1- >R REPEAT DROP   BEGIN
    R@ 0 < WHILE   DROP   R> 1+ >R REPEAT RDROP   TRUE
  ELSE   DUP IF THROW THEN   THEN ;


\ SIGNAL, RESPOND, and PASS

VARIABLE RESPONSE   FP0 RESPONSE !

: SIGNAL   RESPONSE @    DUP 0 @F EXECUTE ;

: RESPOND ( ... xt response-xt -- ... )
  RESPONSE @ >F   >F   FP@ RESPONSE !   CATCH ( ... f )
  F> DROP   F> RESPONSE !   IF THROW THEN   NOTHROW ;

: (PASS)   1 @F   DUP 0 @F EXECUTE ;
: PASS ( rf -* )   POSTPONE (PASS) POSTPONE EXIT ; IMMEDIATE

\ OFFER and AGREE

VARIABLE OFFERS   FP0 OFFERS !

: OFFER ( ... xt -- ... f )
  OFFERS @ >F   FP@   TUCK OFFERS !   CATCH ( ... 0 | of -1 )
  DUP ANDIF OVER FP@ <> THEN   F> OFFERS !   IF DROP THROW THEN
  NOTHROW   DUP IF NIP THEN ;

: AGREE ( of -* )   POSTPONE THROW ; IMMEDIATE

\ Class system

HERE CELL+ DUP , 1 CELLS ,   CONSTANT TOP

: CLONE ( c "name" -- )   DUP >R   CREATE HERE >R   DUP @
  TUCK - SWAP   [ 2 CELLS ] LITERAL + DUP ,   R> + ,   BEGIN
  DUP R@ < WHILE   DUP @ ,   CELL+ REPEAT   @ CELL+ , RDROP
  DOES>   DUP @ + ;

: EXTENDS ( c1 c2 -- )   OVER @ OVER @ MIN   ROT SWAP - @   = ;
