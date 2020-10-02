version = "0.7.0"
author = "Oleh Prypin"
description = "Command line option parser that will make you smile"
license = "MIT"
srcDir = "src"

requires "nim >= 0.20.0"
requires "regex >= 0.11.1"

task test, "Test":
  exec "nimble c --verbosity:0 -r -y test/test"
  for f in listFiles("examples"):
    if f[^4..^1] == ".nim": exec "nim compile --verbosity:0 --hints:off " & f
