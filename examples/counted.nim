let doc = """
Usage: counted --help
       counted -v...
       counted go [go]
       counted (--path=<path>)...
       counted <file> <file>

Try: counted -vvvvvvvvvv
     counted go go
     counted --path ./here --path ./there
     counted this.txt that.txt
"""

import strutils, unicode
import docopt


let args = docopt(doc)
echo args

if args["-v"]:
    echo unicode.capitalize(repeat("very ", args["-v"].len - 1) & "verbose")

for path in @(args["--path"]):
    echo read_file(path)
