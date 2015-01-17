[docopt][] creates *beautiful* command-line interfaces
======================================================

**This is a port of [docopt][docopt.py] to [Nim][]. Visit [docopt.org][docopt] for more information.**

```nim
let doc = """
Naval Fate.

Usage:
    naval_fate.py ship new <name>...
    naval_fate.py ship <name> move <x> <y> [--speed=<kn>]
    naval_fate.py ship shoot <x> <y>
    naval_fate.py mine (set|remove) <x> <y> [--moored | --drifting]
    naval_fate.py (-h | --help)
    naval_fate.py --version

Options:
    -h --help     Show this screen.
    --version     Show version.
    --speed=<kn>  Speed in knots [default: 10].
    --moored      Moored (anchored) mine.
    --drifting    Drifting mine.
"""

import tables, strutils
import docopt

let args = docopt(doc, version = "Naval Fate 2.0")

if args["move"]:
  echo "Move ship $# to ($#, $#) at $# km/h" % [
    args["<name>"][0], $args["<x>"], $args["<y>"], $args["--speed"]]
```

The option parser is generated based on the docstring above that is passed to `docopt` function. `docopt` parses the usage pattern (`"Usage: ..."`) and option descriptions (lines starting with dash "`-`") and ensures that the program invocation matches the usage pattern; it parses options, arguments and commands based on that. The basic idea is that *a good help message has all necessary information in it to make a parser*.


Installation
------------

`git clone` and `nimble install`


Testing
-------

See [test](test) folder.



[docopt]: http://docopt.org/
[docopt.py]: https://github.com/docopt/docopt
[nim]: http://nim-lang.org/