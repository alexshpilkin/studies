# Conditions in ANS Forth

This may be considered my response to Mitch Bradley's implied
[challenge][1] to come up with a Forth idea that wasn't tried before (or
at least that's how I took it... =) ).  I have tried to implement in ANS
Forth a condition system in the vein of [Common Lisp][2], [Dylan][3],
and [Racket][4].   If that seems too theoretical, the C2 wiki also
[points out][5] that the DOS Abort/Retry/Ignore prompt is
_unimplementable_ on top of exception systems in every modern language
except those three.  The best high-level overview of the idea known to
me is [in _Practical Common Lisp_][6], and its originator Kent Pitman
also wrote an [in-depth discussion][7] of the issues and design choices.
This text will instead proceed from the lowest level up, describing
parts of [the code](condit.fth) in corresponding sections.

## Activation stack

These first two parts are essentially workarounds for inflexibilities in
ANS Forth.  These should be completely straightforward to implement with
carnal knowledge of the system, but are rather awkward and inefficient
in the portable version I give.

In ANS Forth, it's impossible to access earlier frames on the return
stack except by popping until the desired element.  This part implements
what's essentially a parallel return stack, with `>A` and `A>` in place
of `>R` and `R>`, but also `AP@ ( -- fa )` to save the current frame
address and `@A ( fa n -- )` to fetch the `n`th last cell pushed before
`fa` was saved.   There is no supposition here that the frame address
`fa` is in fact an address usable with the usual memory access words---
it could just as well be an offset from `RP0`, for example.  The client
code is also not supposed to know that the frame stack is distinct from
the return stack, so this can be turned into actually usable code as a
part of a Forth system.

## Stack-preserving THROW and CATCH

It puzzles me that [`THROW` and `CATCH`][8], the only non-local control
transfers provided by ANS Forth, as well as both of the early proposals
([`ALERT`/`EXCEPT`/`RESUME`][9] of Guy and Rayburn, which uses a more
convenient syntax, and [`EXCEPTION`/`TRAP`][10] of Roye, which is
essentially `THROW`/`CATCH` by another name) insist on restoring the
data stack pointer after a non-local exit.  This is perhaps suitable if
they are to be used as an error-handling construct exactly as envisioned
by the authors, but completely inappropriate if a general non-local
control transfer is desired, as it is here.

To add insult to injury, ANS-style stack-restoring `THROW` and `CATCH`
are straightforwardly, if a tad inefficiently, implementable in terms of
stack-preserving ones using `DEPTH`, while the opposite requires no
small amount of contortions.  It _is_ possible, though, using auxiliary
global storage, so that is what this part does.  It also takes the
opportunity to save and restore the frame stack pointer, to make the
"parallel return stack" actually track the real one.

A final word of warning: my implementations of `THROW ( -* )` and
`CATCH ( ... xt -- ... f )` use ANS throw code 1 and pass through any
others.  However, this is to be understood more as a debugging aid than
a serious attempt at compatibility: an ANS exception passing through a
condition handling construct will still break things.

## SIGNAL, HANDLE, and DECLINE

This part and the next one implement the logic for doing something when
an abnormal conditional arises and for unwinding the stack if necessary.
The general approach parallels the original [32-bit Windows SEH][11],
though I hope my implementation is not that convoluted.

When a program needs to indicate that something unusual happened, it
puts one _or several_ items describing the situation on the data stack
and calls `SIGNAL`.  This does not in itself relinquish control;
instead, a callback function is called normally.  That callback can
either perform a non-local exit or return to the signaller (in case the
condition was only a warning and got ignored, for example).

The callbacks, called _handlers_, and are installed using
`HANDLE ( ... xt handler-xt -- ... )`.  A stack of handlers is
maintained, and a handler can call the one up the stack using `DECLINE`.
(I should probably specify that `DECLINE` must be in tail position or
make it a non-local exit, but the current implementation doesn't do
either.)  The stack of callbacks is maintained as linked frames on the
frame stack: the handler xt is on top, and the frame address of the
previous handler is below it.  The frame address of the top frame is
stored in (would-be user) variable `HANDLER`, saved and restored by
every `HANDLE` block.  When a handler is invoked, it receives the frame
address `fa` of its own frame on the data stack on top of the
information pushed by the signaller.  The handler can use it to retrieve
additional data from the frame or pass it to `DECLINE ( fa -* )`.

(The slightly backwards frame structure, with the handler above the
link, is to make `SIGNAL` completely oblivious of the links.  I don't
know if it's worth it.)

Unlike other exception systems, this one does not implement the Common
Lisp "condition firewall" or give any other special treatment to
conditions signalled inside a handler.  It's just regular code executing
in the dynamic scope of the signaller.

[1]:  https://github.com/ForthHub/discussion/issues/79#issuecomment-454218065
[2]:  http://www.lispworks.com/documentation/lw71/CLHS/Body/09_.htm
[3]:  https://opendylan.org/books/drm/Conditions
[4]:  https://docs.racket-lang.org/reference/exns.html
[5]:  http://wiki.c2.com/?AbortRetryIgnore
[6]:  http://www.gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts.html
[7]:  http://www.nhplace.com/kent/Papers/Condition-Handling-2001.html
[8]:  https://www.complang.tuwien.ac.at/forth/dpans-html/dpans9.htm
[9]:  http://soton.mpeforth.com/flag/jfar/vol3/no4/article3.pdf
[10]: http://soton.mpeforth.com/flag/jfar/vol5/no2/article4.pdf
[11]: http://bytepointer.com/resources/pietrek_crash_course_depths_of_win32_seh.htm
