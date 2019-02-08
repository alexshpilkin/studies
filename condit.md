# Conditions in ANS Forth

This may be considered my response to Mitch Bradley's implied
[challenge][1] to come up with a Forth idea that wasn't tried before (or
at least that's how I took it... =) ).  I have tried to implement in ANS
Forth a condition system in the vein of [Common Lisp][2], [Dylan][3],
and [Racket][4].  The best high-level overview of the idea known to me
is [in _Practical Common Lisp_][5], and its originator Kent Pitman also
wrote an [in-depth discussion][6] of the issues and design choices.
This text will instead proceed from the lowest level up, describing
parts of the code in corresponding sections.

The two first parts are essentially workarounds for inflexibilities in
the standard.  These should be completely straightforward to implement
with carnal knowledge of the system, but are rather awkward and
inefficient in the portable version I give.

## Activation stack

In ANS Forth, it's impossible to access earlier frames on the return
stack except by popping until the desired element.  This part implements
what's essentially a parallel return stack, with `>A` and `A>` in place
of `>R` and `R>`, but also `AP@ ( -- fa )` to save the current frame
address and `@A ( fa n -- )` to fetch the `n`th last cell pushed before
`fa` was saved.   There is no supposition here that the frame address
`fa` is in fact an address usable with the usual memory access words---
it could just as well be an offset from `RP0`, for example.  The client
code is also not supposed to know that the activation stack is distinct
from the return stack, so this can be turned into actually usable code
as a part of a Forth system.

## Stack-preserving THROW and CATCH

It puzzles me that [`THROW` and `CATCH`][7], the only non-local control
transfers provided by ANS Forth, as well as both of the early proposals
([`ALERT`/`EXCEPT`/`RESUME`][8] of Guy and Rayburn, which uses a more
convenient syntax, and [`EXCEPTION`/`TRAP`][9] of Roye, which is
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
opportunity to save and restore the activation stack pointer, to make
the "parallel return stack" actually track the real one.

A final word of warning: my implementations of `THROW` and `CATCH` use
ANS throw code 1 and pass through any other.  However, this is to be
understood more as a debugging aid than a serious attempt at
compatibility: an ANS exception passing through a condition handling
construct will still break things.

[1]: https://github.com/ForthHub/discussion/issues/79#issuecomment-454218065
[2]: http://www.lispworks.com/documentation/lw71/CLHS/Body/09_.htm
[3]: https://opendylan.org/books/drm/Conditions
[4]: https://docs.racket-lang.org/reference/exns.html
[5]: http://www.gigamonkeys.com/book/beyond-exception-handling-conditions-and-restarts.html
[6]: http://www.nhplace.com/kent/Papers/Condition-Handling-2001.html
[7]: https://www.complang.tuwien.ac.at/forth/dpans-html/dpans9.htm
[8]: http://soton.mpeforth.com/flag/jfar/vol3/no4/article3.pdf
[9]: http://soton.mpeforth.com/flag/jfar/vol5/no2/article4.pdf
