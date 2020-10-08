import json, strutils, tables, options

include docopt


proc test(doc, args, expected_s: string): bool =
  var expected_json = parse_json(expected_s)
  var error = ""
  try:
    try:
      var output = docopt(doc, args.split_whitespace(), quit = false)
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

var args, expected: options.Option[string]
var doc: string
var in_doc = false
var total, passed = 0

const tests = static_read("testcases.docopt")
for each_line in (tests & "\n\n").split_lines():
  var line = each_line.partition("#").left
  if not in_doc and line.starts_with("r\"\"\""):
    in_doc = true
    doc = ""
    line = line.substr(4)
  if in_doc:
    doc &= line
    if line.ends_with("\"\"\""):
      doc = doc[0 .. doc.len-4]
      in_doc = false
    doc &= "\n"
  elif line.starts_with("$ prog"):
    assert args.is_none and expected.is_none
    args = some(line.substr(7))
  elif line.starts_with("{") or line.starts_with("\""):
    assert args.is_some and expected.is_none
    expected = some(line)
  elif line.len > 0:
    assert expected.is_some
    expected = some(expected.get & "\n" & line)
  if line.len == 0 and args.is_some and expected.is_some:
    total += 1
    if test(doc, args.get, expected.get):
      passed += 1
    stdout.write("\rTests passed: $#/$#\r".format(passed, total))
    args = none(string)
    expected = none(string)
echo()

quit(if passed == total: 0 else: 1)
