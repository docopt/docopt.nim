[test]$ nim compile --verbosity:0 --path:../src --run test.nim
-------- TEST NOT PASSED --------
usage: prog [-]
$ prog - 
{"-": true}
!= {-: -}
---------------------------------
-------- TEST NOT PASSED --------
usage: prog [-]
$ prog  
{"-": false}
!= {-: nil}
---------------------------------
-------- TEST NOT PASSED --------
usage: prog [<input file>]
$ prog f.txt 
{"<input file>": "f.txt"}
DocoptExit on valid input
---------------------------------
-------- TEST NOT PASSED --------
usage: prog [--input=<file name>]...
$ prog --input a.txt --input=b.txt 
{"--input": ["a.txt", "b.txt"]}
!= {--input: ["a.txt", "b.txt"], name>: 0}
---------------------------------
Tests passed: 170/174
