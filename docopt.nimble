version = "0.6.8"
author = "Oleh Prypin"
description = "Command line option parser that will make you smile"
license = "MIT"
srcDir = "src"

requires "nim >= 0.15.0"
requires "regex >= 0.7.4"

task test, "Test":
  exec "nimble c --verbosity:0 -r -y test/test"
  for f in listFiles("examples"):
    if f[^4..^1] == ".nim": exec "nim compile --verbosity:0 --hints:off " & f
