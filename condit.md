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

## Frame stack

These first two parts are essentially workarounds for inflexibilities in
ANS Forth.  These should be completely straightforward to implement with
carnal knowledge of the system, but are rather awkward and inefficient
in the portable version I give.

In ANS Forth, it's impossible to access earlier frames on the return
stack except by popping until the desired element.  This part implements
what's essentially a parallel return stack, with `>F` and `F>` in place
of `>R` and `R>`, but also `FP@ ( -- fa )` to save the current frame
address and `@F ( fa n -- )` to fetch the `n`th last cell pushed before
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
data stack pointer.  This is perhaps suitable if they are to be used as
an error-handling construct exactly as envisioned by the authors, but
completely inappropriate if an arbitrary amount of data needs to be
passed during the transfer, as here.

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
an unusual situation arises and for unwinding the stack if necessary.
The general approach parallels the original [32-bit Windows SEH][11],
though I hope my implementation is not that convoluted.

When a program needs to indicate that something unusual happened, it
puts one _or several_ items describing the situation on the data stack
and calls `SIGNAL`.  This does not in itself relinquish control;
instead, a callback routine is called normally.  That routine can either
perform a non-local exit or return to the signaller (in case this was
only a warning and it got ignored, for example).

The callbacks are called _handlers_ and are installed using
`HANDLE ( ... xt handler-xt -- ... )`.  A stack of handlers is
maintained, and a handler can call the one up the stack using `DECLINE`.
(I should probably specify that `DECLINE` must be in tail position or
make it a non-local exit, but the current implementation doesn't do
either.)  The stack of callbacks is maintained as linked frames on the
frame stack: the handler xt is on top, and the frame address of the
previous handler is below it.  The frame address of the top frame is
stored in (would-be user) variable `HANDLER`, saved and restored by
every `HANDLE` block.  When a handler is invoked, the address `fa` of
its own handler frame is put on the data stack on top of the information
provided by the signaller.  The handler can use it to retrieve
additional data from the frame or pass it to `DECLINE ( fa -* )`.

(The slightly backwards frame structure, with the handler above the
link, is to make `SIGNAL` completely oblivious of the links.  I don't
know if it's worth it.)

Unlike other exception systems, this one does not implement the Common
Lisp "condition firewall" or give any other special treatment to
conditions signalled inside a handler.  It's just regular code executing
in the dynamic scope of the signaller.

## OFFER and AGREE

A handler does not have to perform a non-local exit, but if an error was
signalled, it will probably want to, whether to retry the operation from
some predetermined point, to return a substitute value from it, or to
abort it.  The non-local exit provided by `THROW` and would be suitable
here, were it not so indiscriminate: `THROW` passes control to the
closest `CATCH`, and that's it.  The ability to list or inspect the
available exits would also be useful.

Thus, `OFFER` and `AGREE` implement on top of Forth `THROW` and `CATCH`
a capability that is closer to their [Common Lisp][12] and [MACLISP][13]
counterparts: an exit point established with `OFFER ( ... xt -- ... f )`
is uniquely identified by its _offer tag_, which is passed to `xt` on
top of the data stack, and `AGREE ( tag -* )` requires the tag of the
exit it should take.  The offer stack can also be inspected, as it is
maintained as linked frames on the frame stack:  each exit frame has the
frame address of the previous frame on top, and the frame address is
stored in (would-be user) variable `OFFERS`.  An offer tag is simply the
address of the corresponding offer frame.

The actual implementation of `AGREE` is then simply `THROW`, while
`OFFER`, after performing a `CATCH`, compares the exit tag on top of the
data stack with the current frame address and either exits to user code
or re`THROW`s, taking the offer frame it created off the offer stack in
both cases.  Unfortunately, this protocol has to more or less monopolize
`THROW` and `CATCH`.  A notable exception is cleanup code that must be
executed every time control goes out of a protected block of code: this
cannot be implemented with `OFFER` and `AGREE` and must instead be done
using `THROW` and `CATCH` themselves:

	protected-xt CATCH ( cleanup code ) IF THROW THEN

The cleanup code cannot rely on the state of the data stack, of course,
but things can be passed to it on the return stack instead.

_Obscure prior work note:_ The Common Lisp implementation of this is
more limited, as described in [X3J13 issue EXIT-EXTENT][14].  Let an
offer called A be established first, then inside it an offer called B,
then inside that a cleanup `CATCH` as above called C, then let the code
inside that agree to A, so the cleanup code of C is now executing.  The
issue is whether that cleanup code can agree to B, which is closer in
the call stack than the original A it is supposed to continue to.
Common Lisp allows systems to prohibit this (proposal MINIMAL in the
issue writeup), but this implementation allows it (proposal MEDIUM).  I
think the latter is cleaner, because exit scope is dynamic scope, and
dynamic scope is dynamic scope is dynamic scope, but apparently the
Common Lisp implementers disagreed.

## Class system

What is implemented up to this point is not a complete condition system,
but only a foundation for one: while there is a mechanism for handlers
to receive data about a condition and accept or decline to handle it,
there is no agreed protocol for doing so.  Similarly, while there is a
way to enumerate available exit points and their associated information
and to exit to a chosen one, possibly passing some data on the stack,
there is no protocol for performing the choice.  This is what remains
to be done: in [SysV ABI terms][15], the "personality".

Following usual terminology, I call unusual situations that are handled
by the system _conditions_, and the offers giving ways of recovery from
those situations _restarts_.  Condition information is put on the data
stack before calling `SIGNAL`, and each handler uses the contents of its
frame to decide whether to accept or `DECLINE`.  Similarly, handler code
that wishes to recover can walk the offer frames and use the data there
to select the desired restart, then put any recovery information on the
data stack alongside the tag before invoking it using `OFFER`.  In both
cases, more specific information should be placed below less specific,
so that the handler or restart code can still work even if it is only
prepared to handle a less specific kind of condition or restart.

What we need, then, is a way of organizing the various kinds of
conditions and restarts in a hierarchy by specificity.  After thinking
about this for some time, I couldn't come up with anything better than
just doing a simple single-inheritance, [prototype-based][16] object
system.  The way it is used is a bit unusual, though: the objects are
statically allocated and represent not the conditions or restarts
themselves, but the kinds of condition or restart, so I call it a class
system instead of an object system.

To signal a particular condition, put the data corresponding to that
condition on the data stack, topped off by the condition class, then
execute `SIGNAL`.  The innermost handler for which the signalled
condition class `EXTENDS` the handled one will accept.  The protocol
for restarts is similar and will be described later.

We see that very little is required of classes: we must be able to tell
whether one class `EXTENDS` another one, and strictly speaking that's
it.  I've also included rudimentary support for _slots_, that is, values
associated with a class that can be overriden by an extending class.  A
slot that stores an xt can be used like a method in a traditional object
system.  When used in a condition or restart class, methods will want to
inspect the data left below the class itself, but, contrary to the usual
Forth convention, they should _not_ consume it: a method cannot know if
there are more items on the stack than it expects, and the user cannot
know how many items a method expects, unless they know in advance what
the exact class is, which would defeat the point of classes.

(Of course, there could be a standard `DUPLICATE` method or a `SIZE`
slot.  I don't think that would improve things compared to just not
consuming the data.)

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
[12]: http://clhs.lisp.se/Body/s_catch.htm
[13]: http://www.maclisp.info/pitmanual/contro.html#5.13.1
[14]: http://clhs.lisp.se/Issues/iss152_w.htm
[15]: https://stackoverflow.com/q/16597350
[16]: http://wiki.c2.com/?PrototypeBasedProgramming
