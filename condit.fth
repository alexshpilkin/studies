\ Conditions

\ Activation stack, essentially a mirror of the return stack

CREATE AP0   32 CELLS ALLOT   VARIABLE AP   AP0 AP !
: AP@ ( -- ap )   AP @ ;
: >A ( x -- )   AP @   DUP CELL+ AP !       ! ;
: A> ( -- x )   AP @   1 CELLS - DUP AP !   @ ;
: @A ( n ap -- x )   SWAP CELLS - @ ;

\ Stack-preserving THROW/CATCH in terms of ANS EXCEPTION words

VARIABLE CATCHDEPTH   VARIABLE STASHDEPTH
CREATE STASH   32 CELLS ALLOT

: CATCH ( ... xt -- ... f )
  CATCHDEPTH @ >R   DEPTH 1- CATCHDEPTH !   AP @ >R   CATCH
  R> AP !   R> CATCHDEPTH !   ( ... error ) DUP 1 = IF DROP
    STASHDEPTH @   DUP >R CELLS STASH + BEGIN   R@ 0 > WHILE
    1 CELLS - DUP @ SWAP   R> 1- >R REPEAT DROP   BEGIN
    R@ 0 < WHILE   DROP   R> 1+ >R REPEAT RDROP   TRUE
  ELSE   DUP IF THROW THEN   THEN ;

: THROW ( ... -* )   DEPTH CATCHDEPTH @ - DUP STASHDEPTH !
  >R STASH BEGIN   R@ 0 > WHILE   TUCK ! CELL+   R> 1- >R REPEAT
  RDROP   1 THROW ;

\ Class system

CREATE TOP   0 ,
: CLASS ( c "name" -- )   CREATE HERE SWAP   DUP @ CELL+ DUP ,
  OVER + >R   CELL+ BEGIN   DUP R@ < WHILE   DUP @ ,   CELL+
  REPEAT DROP RDROP   , ;
: EXTENDS ( c1 c2 -- )   OVER @ OVER @ MIN   ROT + @   = ;
