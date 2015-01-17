import json, strutils, tables

include docopt


proc test(doc, args, expected_s: string): bool =
    var expected_json = parse_json(expected_s)
    var error = ""
    try:
        try:
            var output = docopt(doc, args.split())
            var expected = init_table[string, Value]()
            for k, v in expected_json:
                expected[k] = case v.kind
                  of JNull: val()
                  of JString: val(v.str)
                  of JInt: val(int(v.num))
                  of JBool: val(v.bval)
                  of JArray: val(v.elems.map_it(string, it.str))
                  else: val()
            error = "!= " & $output
            assert expected == output
        except DocoptExit:
            error = "DocoptExit on valid input"
            assert expected_json.kind == JString and
              expected_json.str == "user-error"
        return true
    except AssertionError:
        echo "-------- TEST NOT PASSED --------"
        echo doc
        echo "$ prog ", args, " "
        echo expected_s
        echo error
        echo "---------------------------------"
        return false

var doc, args, expected: string = nil
var in_doc = false
var total, passed = 0

for each_line in "testcases.docopt".lines:
    var line = each_line.partition("#").left
    if not in_doc and line.starts_with("r\"\"\""):
        in_doc = true
        doc = ""
        line = line.substr(4)
    if in_doc:
        doc &= line & "\n"
        if line.ends_with("\"\"\""):
            doc = doc[0 .. -5]
            in_doc = false
    elif line.starts_with("$ prog"):
        assert args == nil and expected == nil
        args = line.substr(7)
    elif line.starts_with("{") or line.starts_with("\""):
        assert args != nil and expected == nil
        expected = line
    elif line.len > 0:
        assert expected != nil
        expected &= "\n" & line
    if line.len == 0 and args != nil and expected != nil:
        total += 1
        if test(doc, args, expected):
            passed += 1
        stdout.write("\rTests passed: $#/$#\r" % [$passed, $total])
        args = nil
        expected = nil
