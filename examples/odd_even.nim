let doc = """
Usage: odd_even [-h | --help] (ODD EVEN)...

Example, try:
  odd_even 1 2 3 4

Options:
  -h, --help
"""

import docopt


let args = docopt(doc)
echo args

for i in 0 ..< args["ODD"].len:
  echo args["ODD"][i] & " " & args["EVEN"][i]
