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
import sequtils

type CustomInt* = distinct int

# You can name a proc `to<type name>` in order to have the dispatcher be able
# to marshall your custom types.
proc toCustomInt*(v: Value): CustomInt =
  CustomInt(parseInt($v))

import docopt/dispatch

let args = docopt(doc, version = "Naval Fate 2.0")

# Define procedures with parameters named the same as the arguments
proc newShip(name: seq[string]) =
  for ship in name:
    echo "Creating ship $#" % ship

proc moveShip(name: string, x, y: int, speed: int) =
  echo "Moving ship $# to ($#, $#) at $# kn".format(
    name, x, y, speed)

proc shootShip(x, y: CustomInt) = # This works because we have `toCustomInt` defined above
  echo "Shooting ship at ($#, $#)".format(x.int, y.int)

# These procedures are not used below, but could be used similar to those above
proc setMine(x, y: int, moored, drifting: bool) =
  echo "Setting $# mine at ($#, $#)".format(
    (if moored: "moored" elif drifting: "drifting" else: ""),
    x, y)

proc removeMine(x, y: int) =
  echo "Removing mine at ($#, $#)".format(x, y)

# This procedure is named the same as an argument so it can be passed directly
# to `dispatchProc` without supplying a list of arguments to match. When no
# list is supplied it will simply check for an argument named the same as the
# procedure.
proc mine(x, y: int, moored, remove: bool) =
  if remove:
    echo "Removing mine at ($#, $#)".format(x, y)
  else:
    echo "Setting $# mine at ($#, $#)".format(
      (if moored: "moored" else: "drifting"),
      x, y)

if args.dispatchProc(newShip, "ship", "new") or # Runs newShip when "ship" and "new" is set
  args.dispatchProc(moveShip, "ship", "move") or # Runs newShip when "ship" and "move" is set
  args.dispatchProc(shootShip, "ship", "shoot") or # Runs newShip when "ship" and "shoot" is set
  args.dispatchProc(mine): # Runs mine when "mine" is set
  echo "Ran something"
else:
  echo doc

# Instead of the `mine` dispatcher above these could be used instead
#args.dispatchProc(setMine, "mine", "set")
#args.dispatchProc(removeMine, "mine", "remove")
