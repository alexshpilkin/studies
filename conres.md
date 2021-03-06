# Conditions and restarts

This may be considered my response to Mitch Bradley's implied
[challenge][1] to come up with a Forth idea that wasn't tried before (or
at least that's how I took it... =) ).  I have tried to implement in ANS
Forth a condition and restart system in the vein of [Common Lisp][2],
[Dylan][3], and [Racket][4].  If that seems too theoretical, the C2 wiki
also [points out][5] that the DOS Abort/Retry/Ignore prompt is
_unimplementable_ on top of exception systems in every modern language
except those three.  The best high-level overview of the idea known to
me is [in _Practical Common Lisp_][6], and its originator Kent Pitman
also wrote an [in-depth discussion][7] of the issues and design choices.
This text will instead proceed from the lowest level up, describing
parts of the [code](conres.fth) in corresponding sections.

There's nothing particularly non-obvious about this code; given an
active imagination, one could even claim it does nothing but mix the
well-known ideas of error callbacks and non-local exits in a particular
way, any obscure Lisp influences notwithstanding.  I still think it's
remarkable how this particular combination of these ideas achieves a
decoupling of error policy and mechanisms in a way that conventional
exception systems can't.

## Frame stack

These first two parts are essentially workarounds for inflexibilities in
ANS Forth.  These should be completely straightforward to implement with
carnal knowledge of the system, but are rather awkward and inefficient
in the portable version I give.

In ANS Forth, it's impossible to access earlier frames on the return
stack except by popping until the desired element.  This part implements
what's essentially a parallel return stack, with `>F` and `F>` in place
of `>R` and `R>`, but also `FP@ ( -- fp )` to save the current frame
pointer and `@F ( fp n -- )` to fetch the `n`th last cell pushed before
`fp` was saved.  There is no supposition here that the frame pointer
`fp` is in fact an address usable with the usual memory access words---
it could just as well be an offset from `FP0`, for example.  The client
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
opportunity to save and restore the frame pointer, to make the "parallel
return stack" actually track the real one.

The data stack depth can be saved on the return stack and restored back
manually by `MARK` and `TRIM`, but only if it has become greater in the
meantime.

A final word of warning: my implementations of `THROW ( -* )` and
`CATCH ( ... xt -- ... f )` use ANS throw code 1 and pass through any
others.  However, this is to be understood more as a debugging aid than
a serious attempt at interoperability: an ANS exception passing through
a condition handling construct will still break things.  Actual
interoperability is possible, but would disrupt the logical layering of
code that this presentation uses.

## SIGNAL, RESPOND, and PASS

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

The callbacks are called _responses_ and are installed using
`RESPOND (... xt response-xt -- ... )`.  A stack of responses is
maintained, and a response can give up and call the one up the stack
using `PASS`.  (In a real implementation `PASS` would do a tail call.)
The stack of callbacks is maintained as linked frames on the frame
stack: the response xt is on top, and the pointer to the previous
response frame is below it.  The pointer to the top frame is stored in
(would-be user) variable `RESPONSE`, saved and restored by every
`RESPOND` block.  When a response is invoked, the pointer `rf` to its
own response frame is put on the data stack on top of the information
provided by the signaller.  The response can use it to retrieve
additional data from the frame or pass it to `PASS ( rf -* )`.

(The slightly backwards frame structure, with the xt above the link, is
to make `SIGNAL` completely oblivious of the links.  I don't know if
it's worth it.)

Unlike other systems, this one does not implement the Common Lisp
"condition firewall" or give any other special treatment to signalling
inside a response.  A response just regular code executing in the
dynamic scope of the signaller.

## ESCAPE and RESUME

A response does not have to perform a non-local exit, but if an error
was signalled, it will probably want to, whether to retry the operation
from some predetermined point, to return a substitute value from it, or
to abort it.  The non-local exit provided by `THROW` and would be
suitable here, were it not so indiscriminate: `THROW` passes control to
the closest `CATCH`, and that's it.

Thus, `ESCAPE` and `RESUME` implement on top of Forth `THROW` and
`CATCH` a capability that is closer to their [Common Lisp][12] and
[MACLISP][13] counterparts: an exit point established with
`RESUME ( ... xt -- ... f )` is uniquely identified by its _tag_, which
is passed to `xt` on top of the data stack, and `ESCAPE ( tag -* )`
requires the tag of the exit it should take.

The tag is implemented as the frame pointer at the moment `RESUME` is
entered.  The actual implementation of `ESCAPE` is then simply `THROW`,
while `RESUME`, after performing a `CATCH`, compares the tag on top of
the data stack with the current frame pointer and either exits to user
code or re`THROW`s.  Unfortunately, this protocol has to more or less
monopolize `THROW` and `CATCH`.  A notable exception is cleanup code
that must be executed every time control goes out of a protected block
of code: this cannot be implemented with `ESCAPE` and `RESUME` and must
instead be done using `THROW` and `CATCH` themselves:

	protected-xt CATCH ( cleanup code ) IF THROW THEN

The cleanup code cannot rely on the state of the data stack, of course,
but things can be passed to it on the return stack instead.

_Obscure prior work note:_ The Common Lisp implementation of this is
more limited, as described in [X3J13 issue EXIT-EXTENT][14].  Let a
`RESUME` called A be established first, then inside it a `RESUME` called
B, then inside that a cleanup `CATCH` as above called C, then let the
code inside that escape to A, so the cleanup code of C is now executing.
The issue is whether that cleanup code can escape to B, which is closer
in the call stack than the original A it is supposed to continue to.
Common Lisp allows systems to prohibit this (proposal MINIMAL in the
issue writeup), but this implementation allows it (proposal MEDIUM).  I
think the latter is cleaner, because exit scope is dynamic scope, and
dynamic scope is dynamic scope is dynamic scope, but apparently the
Common Lisp implementers disagreed.

## Class system

What is implemented up to this point is not a complete condition and
restart system, but only a foundation for one: while there is a
mechanism to receive data about an unusual situation and accept or
decline to handle it, there is no agreed protocol for doing so.
Similarly, while there is a way to escape to a chosen resumption point,
possibly passing some data on the stack, there is no protocol for
performing the choice.  This is what remains to be done: in SysV ABI
terms, the "[personality][15]".

Following common terminology, I call unusual situations that are handled
by the system _conditions_, the responses to them _handlers_, and the
ways of recovery from those situations _restarts_.  Condition data is
put on the data stack before calling `SIGNAL`, and each handler uses the
contents of its frame to decide whether to handle or `PASS`.  A restart
is simply a condition whose handler, by convention, immediately escapes
to the restart code, leaving the restart data intact on the data stack.
In both cases, more specific data should be placed below less specific,
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
condition class `EXTENDS` the handled one will handle it.  The protocol
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

## HANDLE

The protocol for signalling conditions has already been described above:
put the condition data and condition class on the stack, then call
`SIGNAL`.  To handle subclasses of a class `c` using `handler-xt` during
execution of `xt`, call `HANDLE ( ... xt handler-xt c -- ... )`.  The
handler receives the pointer to its own frame on top of the class; the
last cell put on the frame stack before `HANDLE` is accessible using
`4 @F` (and so on for earlier cells).  Returning from the handler causes
execution to resume after `SIGNAL`.

Slot 1 (or `>UNHANDLED`) of every condition specifies the default
handler for that condition, that will be executed if no handler on the
stack accepts responsibility for it.  The default handler, unlike the
usual ones, is invoked with the condition class on top of the stack.
Slot 2 (`>DISPLAY`) should contain the xt that prints the condition data
on the console in a user-readable form (leaving the stack intact).
Additionally, the description of every condition should specify whether
a handler is allowed to return or whether it has to invoke a restart.

The base class for bug and error conditions is `?`.  Any classes
extending it should have names ending with `?` and describing the object
or action that encountered a problem, not the problem itself, because
there is usually less arbitrary choice in naming the former: for
example, `I/O?`, not `I/O-ERROR?`; `NAME?`, not `NAME-NOT-FOUND?`.

## RESTART

For now, a handler that wants to escape to code up the call stack can be
established by first establishing a `RESUME`, saving the tag to the
handler frame, and using it to `ESCAPE` when needed.  For handlers that
_always_ want to escape before doing anything else, this operation is
packaged into a single word, `RESTART ( ... xt c -- ... f )`.  Restarts
are simply conditions that are by convention always handled using
`RESTART`.  The base class for restarts is `RESTART?`.  It extends `?`
so as to also serve as a bug condition indicating that an unavailable
restart was signalled.

_Prior work note:_ The idea to make a restart a kind of condition is
originally from Dylan; in Common Lisp, restarts are disjoint from
conditions.  However, the functionality provided by `RESTART` is
desirable in any system, but awkward to implement using restarts as the
sole stack unwinding mechanism, while the reverse is straigtforward.
This implementation uses the simpler Dylan approach.

## Example

The [example](crexam.fth) demonstrates a DOS-style Abort/Retry/Ignore
prompt, with even more modularity than in DOS: the simulated `SYSTEM`
provides the prompt, but has no knowledge of the available recovery
options; the simulated `SHELL` and I/O subsystem provide the options,
and the simulated `APPLICATION` has no knowledge of either.  A serious
attempt at an interactive debugger would probably look a lot like
`SYSTEM`, except it could use system-specific knowledge to implement a
full debugging REPL.  Alternatively, the list of restarts could be
incorporated into the a return stack trace.

Unlike the rest of the code, the example doesn't limit itself to the ANS
CORE wordset; it uses quotations from Forth 200x and INCLUDED from FILE.

## Design issues

This is a proof of concept.  The organization and naming of the words
should generally be sound, but I can only design a limited part of a
system without actually using it first.  The following is a list of
design issues I can see but have decided not to sidestep in this sketch:

* The condition hierarchy needs to be worked out.  There need to be base
  classes for warnings, errors, bugs, implementation limitations.  The
  distinction between bugs and (runtime) errors is particularly
  important, and many languages with exception systems (C++, Java,
  Python...) get it wrong.  It is not clear to me if errors should be a
  particular case of bugs, as in the example, or if the default handler
  for an error should signal a bug; similarly for restarts.  It seems
  that a handler for bugs would usually be installed by an interactive
  toplevel of some sort, so it would make sense for it to also be an
  absolute barrier for any conditions or restarts.  On the other hand,
  there can also be fatal conditions that are not in any sense bugs,
  like `SystemExit` in Python or `ThreadInterruptedException` in Java.

* Restarts being conditions still feels more like an accident than a
  coherent choice; I can't think of a case where a hierarchy of restarts
  could possibly be useful.

* The set of methods on a condition class is a sketch.  Unfortunately,
  no methods can be added to a class once it has been defined, so things
  like `DISPLAY` will have to be baked in.

* An actual implementation of frames using the return stack will need to
  carefully specify which words that create frames (like `HANDLE`) make
  them contiguous with whatever user code put there before.

* Even if frame pointers are not actual addresses, a specification might
  want to declare that they are disjoint from any addresses pointing to
  user-created areas.  (ANS Forth doesn't do this even for xts, though.)

* I don't know how to frame pointers should be passed around.  Wrapping
  code like `(HANDLE)` might want to consume the relevant data on the
  frame and advance the frame pointer it passes to underlying code to a
  point lower on the stack.  This probably composes better, but means
  that, for example, a handler will not be able to call `PASS`.

* Restarts currently don't have user-accessible frames that could be
  used without passing control to the restart, like `LIST-RESTARTS` does
  in the example.  This may or may not be a good idea.  Restart code or
  methods will also want to access the _condition_ it's handling; the
  calling convention requires some thought.

* It's not clear to me that the approach the example uses to enumerate
  available restarts is the best one.  A separate stack containing only
  the restarts is also an option, but then a restart barrier, like a
  handler for `?`, will need to manipulate it explicitly to ensure
  introspection works correctly.

* Words are needed for inspecting and walking the response stack (at
  least equivalent to those used in the example).  I'm not aware of any
  general approaches to looping over arbitrary structures in Forth
  (unlike its more Lispish cousins like Joy or Factor), so this will
  have to be postponed for now.

* The layout of slots and frames is too fragile and requires far too
  much boilerplate in user code.  It might make sense to use some sort
  of structure lexicon to simplify this, but there is a certain appeal
  to defining classes in one pass instead of compiling default data
  first and overwriting it later.

* The syntax in general is downright miserable to use without quotations
  and still awkward with them, similar to ANS Forth exceptions.  A
  syntax more in line with usual Forth control structures, like that of
  the `ALERT`/`EXCEPT`/`RESUME` proposal, might be better, even if it's
  unimplementable in terms of ANS words.  On the other hand, the
  requirement to pack things into a separate xt serves nicely to enforce
  return stack separation that's in any case required by the words.  (In
  this sense, it's the syntax of `DO`/`LOOP` that is the mistake.)

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
