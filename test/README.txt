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
Tests passed: 172/174
