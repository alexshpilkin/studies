\ ESCAPE and RESUME

VARIABLE TAG   1 TAG !

: ESCAPE ( ... tag -* )   THROW ;

: RESUME ( ... xt -- ... f ) ( xt: ... tag -- ... )
  TAG @   DUP 1+ TAG !   SWAP CATCH   TAG @   1- DUP TAG !
  OVER 0= IF DROP EXIT THEN   OVER <> IF THROW THEN   DROP
  DROP TRUE ;

\ there's one more data stack item when CATCH is executed than
\ when RESUME is executed, so two DROPs are needed
