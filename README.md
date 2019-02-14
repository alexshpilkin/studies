# Studies in ANS Forth

This repository contains small, self-contained bits of code (“studies”)
written in ANS-compatible Forth, along with descriptions for them.  The
studies currently include:

* [Conditions and restarts](condit.fth), a condition and restart system
  in the Common Lisp style.  Unlike the ANS Forth exceptions, conditions
  can be handled by restarting execution at one of predetermined points,
  without requiring the handler to know how the restart is implemented
  or the restart code to contain handling policy.  Comes with detailed
  [documentation](condit.md).  Uses only the CORE and EXCEPTION ANS
  wordsets, but overrides several standard words.

Everything here is free to use or modify however you please, with no
legal requirement to give attribution (although of course I’ll
appreciate it if you do so anyway).  See [LICENSE](LICENSE) for details.
