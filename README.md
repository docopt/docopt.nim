[docopt][docopt.org] creates *beautiful* command-line interfaces
================================================================

**This is a port of [docopt][docopt.py] to [Nim][]. Visit [docopt.org][] for more information.**

```nim
let doc = """
Naval Fate.

Usage:
  naval_fate ship new <name>...
  naval_fate ship <name> move <x> <y> [--speed=<kn>]
  naval_fate ship shoot <x> <y>
  naval_fate mine (set|remove) <x> <y> [--moored | --drifting]
  naval_fate (-h | --help)
  naval_fate --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
  --moored      Moored (anchored) mine.
  --drifting    Drifting mine.
"""

import strutils
import docopt

let args = docopt(doc, version = "Naval Fate 2.0")

if args["move"]:
  echo "Moving ship $# to ($#, $#) at $# kn".format(
    args["<name>"], args["<x>"], args["<y>"], args["--speed"])
  ships[$args["<name>"]].move(
    parseFloat($args["<x>"]), parseFloat($args["<y>"]),
    speed = parseFloat($args["--speed"]))

if args["new"]: 
  for name in @(args["<name>"]): 
    echo "Creating ship $#" % name 
```

The option parser is generated based on the docstring above that is passed to `docopt` function. `docopt` parses the usage pattern (`"Usage: ..."`) and option descriptions (lines starting with dash "`-`") and ensures that the program invocation matches the usage pattern; it parses options, arguments and commands based on that. The basic idea is that *a good help message has all necessary information in it to make a parser*.


Documentation
-------------

```nim
proc docopt(doc: string, argv: seq[string] = nil,
            help = true, version: string = nil,
            optionsFirst = false, quit = true): Table[string, Value]
```

`docopt` takes 1 required and 5 optional arguments:

- `doc` is a string that contains a **help message** that will be parsed to create the option parser. The simple rules of how to write such a help message are described at [docopt.org][]. Here is a quick example of such a string:

        Usage: my_program [-hso FILE] [--quiet | --verbose] [INPUT ...]

        -h --help    show this
        -s --sorted  sorted output
        -o FILE      specify output file [default: ./test.txt]
        --quiet      print less text
        --verbose    print more text

- `argv` is an optional argument vector; by default `docopt` uses the argument vector passed to your program (`commandLineParams()`). Alternatively you can supply a list of strings like `@["--verbose", "-o", "hai.txt"]`.

- `help`, by default `true`, specifies whether the parser should automatically print the help message (supplied as `doc`) and terminate, in case `-h` or `--help` option is encountered (options should exist in usage pattern). If you want to handle `-h` or `--help` options manually (as other options), set `help = false`.

- `version`, by default `nil`, is an optional argument that specifies the version of your program. If supplied, then, (assuming `--version` option is mentioned in usage pattern) when parser encounters the `--version` option, it will print the supplied version and terminate. `version` can be any string, e.g. `"2.1.0rc1"`.
  > Note, when `docopt` is set to automatically handle `-h`, `--help` and `--version` options, you still need to mention them in usage pattern for this to work. Also, for your users to know about them.

- `optionsFirst`, by default `false`. If set to `true` will disallow mixing options and positional arguments. I.e. after first positional argument, all arguments will be interpreted as positional even if the look like options. This can be used for strict compatibility with POSIX, or if you want to dispatch your arguments to other programs.

- `quit`, by default `true`, specifies whether [`quit()`][quit] should be called after encountering invalid arguments or printing the help message (see `help`). Setting this to `false` will allow `docopt` to raise a `DocoptExit` exception (with the `usage` member set) instead.

If the `doc` string is invalid, `DocoptLanguageError` will be raised.

The **return** value is a [`Table`][table] with options, arguments and commands as keys, spelled exactly like in your help message. Long versions of options are given priority. For example, if you invoke the top example as:

    naval_fate ship Guardian move 100 150 --speed=15

the result will be:

```nim
{"--drifting": false,     "mine": false,
 "--help": false,         "move": true,
 "--moored": false,       "new": false,
 "--speed": "15",         "remove": false,
 "--version": false,      "set": false,
 "<name>": @["Guardian"], "ship": true,
 "<x>": "100",            "shoot": false,
 "<y>": "150"}
```

Note that this is not how the values are actually stored, because a `Table` can hold values of only one type. For that reason, a variant `Value` type is needed. `Value`'s only accessible member is `kind: ValueKind` (which shouldn't be needed anyway, because it is known beforehand). `ValueKind` is one of:

- `vkNone` (No value)

  This kind of `Value` appears when there is an option which hasn't been set and has no default. It is `false` when converted `toBool`.

- `vkBool` (A boolean)

  This represents whether a boolean flag has been set or not. Just use it in a boolean context (conversion `toBool` is present).

- `vkInt` (An integer)

  An integer represents how many times a flag has been repeated (if it is possible to supply it multiple times). Use `value.len` to obtain this `int`, or just use the value in a boolean context to find out whether this flag is present at least once.

- `vkStr` (A string)

  Any option that has a user-supplied value will be represented as a `string` (conversion to integers, etc, does not happen). To obtain this string, use `$value`.

- `vkList` (A list of strings)

  Any value that can be supplied multiple times will be represented by a `seq[string]`, even if the user provides just one. To obtain this `seq`, use `@value`. To obtain its length, use `value.len` or `@value.len`. To obtain the n-th value (0-indexed), both `value[i]` and `@value[i]` will work. If you are sure there is exactly one value, `$value` is the same as `value[0]`.

Note that you can use any kind of value in a boolean context and convert any value to `string`.

Look [in the source code](src/docopt/value.nim) to find out more about these conversions.

As of version 0.7.0 docopt also includes a dispatch mechanism for automatically
running procedures and converting arguments. This works by a simple macro that
inspects the signature of the given procedure. The macro then returns code that
will inspect the parsed arguments and if a list of supplied conditions are
true the matched arguments from the signature will be extracted from the
arguments and converted to the correct type before the procedure is called. A
simple example would be something like this (a longer example can be found in
the examples folder):

```nim
let doc = """
Naval Fate Lite

Usage:
  naval_fate ship new <name>...
  naval_fate ship <name> move <x> <y> [--speed=<kn>]
  naval_fate (-h | --help)
  naval_fate --version

Options:
  -h --help     Show this screen.
  --version     Show version.
  --speed=<kn>  Speed in knots [default: 10].
"""

import strutils
import docopt
import docopt/dispatch
import sequtils

let args = docopt(doc, version = "Naval Fate Lite")

# Define procedures with parameters named the same as the arguments
proc newShip(name: seq[string]) =
  for ship in name:
    echo "Creating ship $#" % ship

proc moveShip(name: string, x, y: int, speed: int) =
  echo "Moving ship $# to ($#, $#) at $# kn".format(
    name, x, y, speed)

if args.dispatchProc(newShip, "ship", "new") or # Runs newShip if "ship" and "new" is set
  args.dispatchProc(moveShip, "ship", "move"): # Runs newShip if "ship" and "move" is set
  echo "Ran something"
else:
  echo doc
```


Examples
--------

See [examples](examples) folder.

For more examples of docopt language see [docopt.py examples][].


Installation
------------

    nimble install docopt

This library has no dependencies outside the standard library. An impure [`re`][re] library is used.





[docopt.org]: http://docopt.org/
[docopt.py]: https://github.com/docopt/docopt
[docopt.py examples]: https://github.com/docopt/docopt/tree/master/examples
[nim]: http://nim-lang.org/
[re]: https://nim-lang.org/docs/re.html
[table]: https://nim-lang.org/docs/tables.html
[quit]: https://nim-lang.org/docs/system.html#quit%2Cint
