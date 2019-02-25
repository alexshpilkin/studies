# Studies in ANS Forth

This repository contains small, self-contained bits of code (“studies”)
written in ANS-compatible Forth, along with descriptions for them.  The
studies currently include:

* [ESCAPE and RESUME](escres.fth), an implementation of multiple
  non-local exits identified by exit tags on top of the ANS EXCEPTION
  wordset.  A preparation for the next item.  Comes with a [test
  suite](ertest.fth).  Uses only the CORE and EXCEPTION ANS wordsets.

* [Conditions and restarts](conres.fth), a condition and restart system
  in the Common Lisp style.  Unlike the ANS Forth exceptions, conditions
  can be handled by restarting execution at one of predetermined points,
  without requiring the handler to know how the restart is implemented
  or the restart code to contain handling policy.  Comes with detailed
  [documentation](conres.md), an [example](crexam.fth) and a [test
  suite](crtest.fth).  Uses only the CORE and EXCEPTION ANS wordsets and
  the CORE EXT word `PARSE`, but overrides several standard words.

Everything here is free to use or modify however you please, with no
legal requirement to give attribution (although of course I’ll
appreciate it if you do so anyway).  See [LICENSE](LICENSE) for details.
