let doc = """
Repeatedly output the arguments.

Usage:
  cycle [options] <what>...

Options:
  -h --help                show this help message and exit
  -n <times>               output all the arguments N times [default: infinite]
  --interval <seconds>     wait after every line of output
"""

import strutils, os
import docopt


let args = docopt(doc)
echo args

let infinite = ($args["-n"] == "infinite")
var n: int
if not infinite:
  n = parse_int($args["-n"])

var interval = 0
if args["--interval"]:
  interval = to_int(parse_float($args["--interval"])*1000)

while true:
  for s in @(args["<what>"]):
    echo s

    if interval > 0:
      sleep interval

  if not infinite:
    dec n
    if n <= 0:
      break
