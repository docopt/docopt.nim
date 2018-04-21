# Package
version = "0.6.5"
author = "Oleh Prypin"
description = "Command line option parser that will make you smile"
license = "MIT"
srcDir = "src"
skipDirs = @["private"]

requires "nim >= 0.15.0"

task test, "Test":
  exec "nim compile --verbosity:0 --run test/test"
  exec "for f in examples/*.nim; do nim compile --verbosity:0 --hints:off \"$f\" || exit; done"
