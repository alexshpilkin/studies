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
  CATCHDEPTH @ >R   DEPTH 1- CATCHDEPTH !   AP @ >R   CATCH IF
    STASHDEPTH @   DUP >R CELLS STASH + BEGIN   R@ 0 > WHILE
    1 CELLS - DUP @ SWAP   R> 1- >R REPEAT DROP   BEGIN
    R@ 0 < WHILE   DROP   R> 1+ >R REPEAT RDROP   TRUE
  ELSE 0 THEN   R> AP !   R> CATCHDEPTH ! ;

: THROW ( ... -* )   DEPTH CATCHDEPTH @ - DUP STASHDEPTH !
  >R STASH BEGIN   R@ 0 > WHILE   TUCK ! CELL+   R> 1- >R REPEAT
  RDROP   1 THROW ;

: TEST-NOTHROW   ;
: TEST-NOCATCH   ['] TEST-NOTHROW CATCH ;
\ result: 0

: TEST-UNDERTHROW   >A THROW ;
: TEST-UNDERCATCH   1 2 >A 3   ['] TEST-UNDERTHROW CATCH AND   A> ;
\ result: 1 2

: TEST-OVERTHROW   4 5 THROW ;
: TEST-OVERCATCH   3   ['] TEST-OVERTHROW CATCH AND ;
\ result: 3 4 5

: TEST-NESTTHROW   TEST-NOCATCH TEST-UNDERCATCH
  TEST-OVERCATCH THROW ;
: TEST-NESTCATCH   -2 -1 ['] TEST-NESTTHROW CATCH AND ;
\ result: -2 -1 0 1 2 3 4 5

\ Class system

CREATE TOP   0 ,
: CLASS ( c "name" -- )   CREATE HERE SWAP   DUP @ CELL+ DUP ,
  OVER + >R   CELL+ BEGIN   DUP R@ < WHILE   DUP @ ,   CELL+
  REPEAT DROP RDROP   , ;
: EXTENDS ( c1 c2 -- )   OVER @ OVER @ MIN   ROT + @   = ;

TOP CLASS FOO
: TEST-FOO   FOO DUP   DUP @ SWAP   CELL+ DUP @ SWAP   DROP ;
\ result: x 1cells x
FOO CLASS BAR
: TEST-BAR   BAR DUP   DUP @ SWAP   CELL+ DUP @ SWAP
  CELL+ DUP @ SWAP   DROP ;
\ result: y 2cells x y
BAR CLASS BAZ
: TEST-BAZ   BAZ DUP   DUP @ SWAP   CELL+ DUP @ SWAP
  CELL+ DUP @ SWAP   CELL+ DUP @ SWAP   DROP ;
\ result: z 3cells x y z
: TEST-EXTENDS   BAZ FOO EXTENDS  BAR BAZ EXTENDS ;
\ result: true false
