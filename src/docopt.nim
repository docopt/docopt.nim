# Copyright (C) 2012-2014 Vladimir Keleshev <vladimir@keleshev.com>
# Copyright (C) 2015 Oleh Prypin <blaxpirit@gmail.com>
# Licensed under terms of MIT license (see LICENSE)


import re, sequtils, strutils, macros, os, tables
import private/util

export tables

type ValueKind* = enum
    vkNone, ## No value
    vkBool, ## A boolean
    vkInt,  ## An integer
    vkStr,  ## A string
    vkList  ## A list of strings

type Value* = object  ## docopt variant type
    case kind*: ValueKind
      of vkNone:
        nil
      of vkBool:
        bool_v: bool
      of vkInt:
        int_v: int
      of vkStr:
        str_v: string
      of vkList:
        list_v: seq[string]


converter to_bool*(v: Value): bool =
    ## Convert a Value to bool, depending on its kind:
    ## - vkNone: false
    ## - vkBool: boolean value itself
    ## - vkInt: true if integer is not zero
    ## - vkStr: true if string is not empty
    ## - vkList: true if sequence is not empty
    case v.kind
      of vkNone: false
      of vkBool: v.bool_v
      of vkInt: v.int_v != 0
      of vkStr: v.str_v != nil and v.str_v.len > 0
      of vkList: not v.list_v.is_nil and v.list_v.len > 0

proc len*(v: Value): int =
    ## Return the integer of a vkInt Value
    ## or the length of the seq of a vkList value.
    ## It is an error to use it on other kinds of Values.
    if v.kind == vkInt: v.int_v
    else: v.list_v.len

proc str(v: Value): string

proc `$`*(v: Value): string =
    ## Return the string of a vkStr Value,
    ## or the item of a vkList Value, if there is exactly one,
    ## or a string representation of any other kind of Value.
    if v.kind == vkStr:
        v.str_v
    elif v.kind == vkList and
      not v.list_v.is_nil and v.list_v.len == 1:
        v.list_v[0]
    else: v.str

proc `@`*(v: Value): seq[string] =
    ## Return the seq of a vkList Value.
    ## It is an error to use it on other kinds of Values.
    v.list_v

proc `[]`*(v: Value, i: int): string =
    ## Return the i-th item of the seq of a vkList Value.
    ## It is an error to use it on other kinds of Values.
    v.list_v[i]


proc val(): Value = Value(kind: vkNone)
proc val(v: bool): Value = Value(kind: vkBool, bool_v: v)
proc val(v: int): Value = Value(kind: vkInt, int_v: v)
proc val(v: string): Value = Value(kind: vkStr, str_v: v)
proc val(v: seq[string]): Value = Value(kind: vkList, list_v: v)


proc str(s: string): string =
    if s.is_nil: "nil"
    else: "\"" & s.replace("\"", "\\\"") & "\""

proc str[T](s: seq[T]): string =
    if s.is_nil: "nil"
    else: "[" & s.map_it(string, it.str).join(", ") & "]"

proc str(v: Value): string =
    case v.kind
      of vkNone: "nil"
      of vkStr: v.str_v.str
      of vkInt: $v.int_v
      of vkBool: $v.bool_v
      of vkList: v.list_v.str


proc `==`*(a, b: Value): bool =
    a.kind == b.kind and a.str == b.str


type DocoptLanguageError* = object of Exception
    ## Error in construction of usage-message by developer.

type DocoptExit* = object of Exception
    ## Exit in case user invoked program with incorrect arguments.
    usage*: string


macro gen_class(typ): stmt =
    parse_stmt("method class(self: $1): string = \"$1\"".format(typ))


type Pattern = ref object of RootObj
    m_name: string
    value: Value
    children: seq[Pattern]
gen_class(Pattern)

type LeafPattern = ref object of Pattern
    ## Leaf/terminal node of a pattern tree.
gen_class(LeafPattern)

type BranchPattern = ref object of Pattern
    ## Branch/inner node of a pattern tree.
gen_class(BranchPattern)

type Argument = ref object of LeafPattern
gen_class(Argument)

proc argument(name: string, value = val()): Argument =
    Argument(m_name: name, value: value)

type Command = ref object of Argument
gen_class(Command)

proc command(name: string, value = val(false)): Command =
    Command(m_name: name, value: value)

type Option = ref object of LeafPattern
    short: string
    long: string
    argcount: int
gen_class(Option)

proc option(short, long: string = nil, argcount = 0,
            value = val(false)): Option =
    assert argcount in [0, 1]
    result = Option(short: short, long: long,
                    argcount: argcount, value: value)
    if value.kind == vkBool and value.bool_v == false and argcount > 0:
        result.value = val()

type Required = ref object of BranchPattern
gen_class(Required)

proc required(children: openarray[Pattern]): Required =
    Required(children: @children)

type Optional = ref object of BranchPattern
gen_class(Optional)

proc optional(children: openarray[Pattern]): Optional =
    Optional(children: @children)

type OptionsShortcut = ref object of Optional
    ## Marker/placeholder for [options] shortcut.
gen_class(OptionsShortcut)

proc options_shortcut(children: openarray[Pattern]): OptionsShortcut =
    OptionsShortcut(children: @children)

type OneOrMore = ref object of BranchPattern
gen_class(OneOrMore)

proc one_or_more(children: openarray[Pattern]): OneOrMore =
    OneOrMore(children: @children)

type Either = ref object of BranchPattern
gen_class(Either)

proc either(children: seq[Pattern]): Either =
    Either(children: @children)


type MatchResult = tuple[matched: bool; left, collected: seq[Pattern]]
type SingleMatchResult = tuple[pos: int, match: Pattern]



method str(self: Pattern): string =
    assert false; "Not implemented"

method name(self: Pattern): string =
    self.m_name
method `name=`(self: Pattern, name: string) =
    self.m_name = name

method `==`(self, other: Pattern): bool =
    self.str == other.str

method flat(self: Pattern, types: openarray[string]): seq[Pattern] =
    assert false; nil

method match(self: Pattern, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    assert false; nil

method fix_identities(self: Pattern, uniq: seq[Pattern]) =
    ## Make pattern-tree tips point to same object if they are equal.
    if self.children.is_nil:
        return
    for i, child in self.children:
        if child.children.is_nil:
            assert child in uniq
            self.children[i] = uniq[uniq.find(child)]
        else:
            child.fix_identities(uniq)

method fix_identities(self: Pattern) =
    self.fix_identities(self.flat([]).deduplicate())

method transform(pattern: Pattern): Either =
    ## Expand pattern into an (almost) equivalent one, but with single Either.
    ##
    ## Example: ((-a | -b) (-c | -d)) => (-a -c | -a -d | -b -c | -b -d)
    ## Quirks: [-a] => (-a), (-a...) => (-a -a)
    var result: seq[seq[Pattern]] = @[]
    var groups: seq[seq[Pattern]] = @[@[pattern]]
    while groups.len > 0:
        var children = groups[0]
        groups.delete()
        var classes = children.map_it(string, it.class)
        var parents = ["Required", "Optional", "OptionsShortcut",
                       "Either", "OneOrMore"]
        if parents.any_it(it in classes):
            var child: Pattern
            for i, c in children:
                if c.class in parents:
                    child = c
                    children.delete(i, i)
                    break
            assert child != nil
            if child.class == "Either":
                for c in child.children:
                    groups.add(@[c] & children)
            elif child.class == "OneOrMore":
                groups.add(child.children & child.children & children)
            else:
                groups.add(child.children & children)
        else:
            result.add(children)
    either(result.map_it(Pattern, required(it)))

method fix_repeating_arguments(self: Pattern) =
    ## Fix elements that should accumulate/increment values.
    var either: seq[seq[Pattern]] = @[]
    for child in transform(self).children:
        either.add(@(child.children))
    for cas in either:
        for e in cas:
            if cas.count(e) <= 1:
                continue
            if e.class == "Argument" or
              e.class == "Option" and Option(e).argcount > 0:
                if e.value.kind == vkNone:
                    e.value = val(@[])
                elif e.value.kind != vkList:
                    e.value = val(e.value.str_v.split())
            if e.class == "Command" or
              e.class == "Option" and Option(e).argcount == 0:
                e.value = val(0)

method fix(self: Pattern) =
    self.fix_identities()
    self.fix_repeating_arguments()


method str(self: LeafPattern): string =
    "$#($#, $#)".format(self.class, self.name.str, self.value.str)

method flat(self: LeafPattern, types: openarray[string]): seq[Pattern] =
    if types.len == 0 or self.class in types: @[Pattern(self)] else: @[]

method single_match(self: LeafPattern,
                    left: seq[Pattern]): SingleMatchResult =
    assert false; nil

method match(self: LeafPattern, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    var m: SingleMatchResult
    try:
        m = self.single_match(left)
    except ValueError:
        return (false, left, collected)
    var (pos, match) = m
    var left2 = left.sub(0, pos) & left.sub(pos+1, left.len)
    var same_name: seq[Pattern] = @[]
    for a in collected:
        if a.name == self.name:
            same_name.add(a)
    if self.value.kind in [vkInt, vkList]:
        var increment =
          if self.value.kind == vkInt: val(1)
          else:
            if match.value.kind == vkStr: val(@[$match.value])
            else: match.value
        if same_name.len == 0:
            match.value = increment
            return (true, left2, collected & @[match])
        if increment.kind == vkInt:
            same_name[0].value.int_v += increment.int_v
        else:
            same_name[0].value.list_v.add(@increment)
        return (true, left2, collected)
    return (true, left2, collected & @[match])


method str(self: BranchPattern): string =
    "$#($#)".format(self.class, self.children.str)

method flat(self: BranchPattern, types: openarray[string]): seq[Pattern] =
    if self.class in types:
        return @[Pattern(self)]
    result = new_seq[Pattern]()
    for child in self.children:
        result.add(child.flat(types))


method single_match(self: Argument, left: seq[Pattern]): SingleMatchResult =
    for n, pattern in left:
        if pattern.class == "Argument":
            return (n, argument(self.name, pattern.value))
    raise new_exception(ValueError, "Not found")

discard """
proc argument_parse[T](
  constructor: proc(name: string, value: Value): T,
  source: Value): T =
    var name = source.find_all(re"<\S*?>")[0]
    var value: seq[string] = @[""]
    if source.find(re.re"(?i)\[default:\ (.*)\]", value) >= 0:
        return constructor(val(value[0]))
    else:
        return constructor(val())
"""


method single_match(self: Command, left: seq[Pattern]): SingleMatchResult =
    for n, pattern in left:
        if pattern.class == "Argument":
            if pattern.value.kind == vkStr and $pattern.value == self.name:
                return (n, command(self.name, val(true)))
            else:
                break
    raise new_exception(ValueError, "Not found")


proc option_parse[T](
  constructor: proc(short, long: string; argcount: int; value: Value): T,
  option_description: string): T =
    var short, long: string = nil
    var argcount = 0
    var value = val(false)
    var (options, p, description) = option_description.strip().partition("  ")
    discard p
    options = options.replace(",", " ").replace("=", " ")
    for s in options.split():
        if s.starts_with("--"):
            long = s
        elif s.starts_with("-"):
            short = s
        else:
            argcount = 1
    if argcount > 0:
        var matched = @[""]
        if description.find(re.re"(?i)\[default:\ (.*)\]", matched) >= 0:
            value = val(matched[0])
        else:
            value = val()
    constructor(short, long, argcount, value)

method single_match(self: Option, left: seq[Pattern]): SingleMatchResult =
    for n, pattern in left:
        if self.name == pattern.name:
            return (n, pattern)
    raise new_exception(ValueError, "Not found")

method name(self: Option): string =
    if self.long != nil: self.long else: self.short

method str(self: Option): string =
    "Option($#, $#, $#, $#)".format(self.short.str, self.long.str,
                                    self.argcount, self.value.str)


method match(self: Required, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    result = (true, left, collected)
    for pattern in self.children:
        result = pattern.match(result.left, result.collected)
        if not result.matched:
            return (false, left, collected)


method match(self: Optional, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    result = (true, left, collected)
    for pattern in self.children:
        result = pattern.match(result.left, result.collected)
    result.matched = true


method match(self: OneOrMore, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    assert self.children.len == 1
    result = (true, left, collected)
    var l2: seq[Pattern]
    var times = 0
    while result.matched:
        # could it be that something didn't match but changed l or c?
        result = self.children[0].match(result.left, result.collected)
        if result.matched:
            times += 1
        if l2 == result.left:
            break
        l2 = result.left
    if times >= 1:
        result.matched = true
    else:
        return (false, left, collected)


method match(self: Either, left: seq[Pattern],
             collected: seq[Pattern] = @[]): MatchResult =
    var found = false
    for pattern in self.children:
        let outcome = pattern.match(left, collected)
        if outcome.matched:
            if not found or outcome.left.len < result.left.len:
                result = outcome
            found = true
    if not found:
        return (false, left, collected)


type Tokens = ref object
    tokens: seq[string]
    error: ref Exception

proc `@`(tokens: Tokens): var seq[string] = tokens.tokens

proc tokens(source: seq[string],
  error: ref Exception = new_exception(DocoptExit, "")): Tokens =
    Tokens(tokens: source, error: error)

proc tokens_from_pattern(source: string): Tokens =
    var source = source.replacef(re"([\[\]\(\)\|]|\.\.\.)", r" $1 ")
    var tokens = source.split_inc(re"\s+|(\S*<.*?>)").filter_it(it.len > 0)
    tokens(tokens, new_exception(DocoptLanguageError, ""))

proc current(self: Tokens): string =
    if @self.len > 0:
        result = @self[0]

proc move(self: Tokens): string =
    result = self.current
    @self.delete()


proc parse_long(tokens: Tokens, options: var seq[Option]): seq[Pattern] =
    ## long ::= '--' chars [ ( ' ' | '=' ) chars ] ;
    var (long, eq, v) = tokens.move().partition("=")
    assert long.starts_with("--")
    var value = (if eq == "" and v == "": val() else: val(v))
    var similar = options.filter_it(it.long == long)
    var o: Option
    if tokens.error of DocoptExit and similar.len == 0:  # if no exact match
        similar = options.filter_it(it.long != nil and
                                    it.long.starts_with(long))
    if similar.len > 1:  # might be simply specified ambiguously 2+ times?
        tokens.error.msg = "$# is not a unique prefix: $#?".format(
          long, similar.map_it(string, it.long).join(", "))
        raise tokens.error
    elif similar.len < 1:
        var argcount = (if eq == "=": 1 else: 0)
        o = option(nil, long, argcount)
        options.add(o)
        if tokens.error of DocoptExit:
            o = option(nil, long, argcount,
                       if argcount > 0: value else: val(true))
    else:
        o = option(similar[0].short, similar[0].long,
                   similar[0].argcount, similar[0].value)
        if o.argcount == 0:
            if value.kind != vkNone:
                tokens.error.msg = "$# must not have an argument".format(o.long)
                raise tokens.error
        else:
            if value.kind == vkNone:
                if tokens.current in [nil, "--"]:
                    tokens.error.msg = "$# requires argument".format(o.long)
                    raise tokens.error
                value = val(tokens.move())
        if tokens.error of DocoptExit:
            o.value = (if value.kind != vkNone: value else: val(true))
    @[Pattern(o)]


proc parse_shorts(tokens: Tokens, options: var seq[Option]): seq[Pattern] =
    ## shorts ::= '-' ( chars )* [ [ ' ' ] chars ] ;
    var token = tokens.move()
    assert token.starts_with("-") and not token.starts_with("--")
    var left = token.lstrip('-')
    result = @[]
    while left != "":
        var short = "-" & left[0]
        left = left.substr(1)
        var similar = options.filter_it(it.short == short)
        var o: Option
        if similar.len > 1:
            tokens.error.msg = "$# is specified ambiguously $# times".format(
              short, similar.len)
            raise tokens.error
        elif similar.len < 1:
            o = option(short, nil, 0)
            options.add(o)
            if tokens.error of DocoptExit:
                o = option(short, nil, 0, val(true))
        else:  # why copying is necessary here?
            o = option(short, similar[0].long,
                       similar[0].argcount, similar[0].value)
            var value = val()
            if o.argcount != 0:
                if left == "":
                    if tokens.current in [nil, "--"]:
                        tokens.error.msg = "$# requires argument".format(short)
                        raise tokens.error
                    value = val(tokens.move())
                else:
                    value = val(left)
                    left = ""
            if tokens.error of DocoptExit:
                o.value = (if value.kind != vkNone: value else: val(true))
        result.add(o)


proc parse_expr(tokens: Tokens, options: var seq[Option]): seq[Pattern]

proc parse_pattern(source: string, options: var seq[Option]): Required =
    var tokens = tokens_from_pattern(source)
    var result = parse_expr(tokens, options)
    if tokens.current != nil:
        tokens.error.msg = "unexpected ending: '$#'".format(@tokens.join(" "))
        raise tokens.error
    required(result)


proc parse_seq(tokens: Tokens, options: var seq[Option]): seq[Pattern]

proc parse_expr(tokens: Tokens, options: var seq[Option]): seq[Pattern] =
    ## expr ::= seq ( '|' seq )* ;
    var sequ = parse_seq(tokens, options)
    if tokens.current != "|":
        return sequ
    var res = (if sequ.len > 1: @[Pattern(required(sequ))] else: sequ)
    while tokens.current == "|":
        discard tokens.move()
        sequ = parse_seq(tokens, options)
        res.add(if sequ.len > 1: @[Pattern(required(sequ))] else: sequ)
    return (if res.len > 1: @[Pattern(either(res))] else: res)



proc parse_atom(tokens: Tokens, options: var seq[Option]): seq[Pattern]

proc parse_seq(tokens: Tokens, options: var seq[Option]): seq[Pattern] =
    ## seq ::= ( atom [ '...' ] )* ;
    result = @[]
    while tokens.current notin [nil, "]", ")", "|"]:
        var atom = parse_atom(tokens, options)
        if tokens.current == "...":
            let oom = one_or_more(atom)
            atom = @[Pattern(oom)]
            discard tokens.move()
        result.add(atom)


proc parse_atom(tokens: Tokens, options: var seq[Option]): seq[Pattern] =
    ## atom ::= '(' expr ')' | '[' expr ']' | 'options'
    ##       | long | shorts | argument | command ;
    var token = tokens.current
    if token in ["(", "["]:
        discard tokens.move()
        var matching: string
        var result: Pattern
        case token
          of "(":
            matching = ")"
            result = required(parse_expr(tokens, options))
          of "[":
            matching = "]"
            result = optional(parse_expr(tokens, options))
          else:
            assert false
        if tokens.move() != matching:
            tokens.error.msg = "unmatched '$#'".format(token)
            raise tokens.error
        return @[result]
    elif token == "options":
        discard tokens.move()
        return @[Pattern(options_shortcut([]))]
    elif token.starts_with("--") and token != "--":
        return parse_long(tokens, options)
    elif token.starts_with("-") and token notin ["-", "--"]:
        return parse_shorts(tokens, options)
    elif token.starts_with("<") and token.ends_with(">") or token.is_upper():
        return @[Pattern(argument(tokens.move()))]
    else:
        return @[Pattern(command(tokens.move()))]


proc parse_argv(tokens: Tokens, options: var seq[Option],
                options_first = false): seq[Pattern] =
    ## Parse command-line argument vector.
    ##
    ## If options_first:
    ##     argv ::= [ long | shorts ]* [ argument ]* [ '--' [ argument ]* ] ;
    ## else:
    ##     argv ::= [ long | shorts | argument ]* [ '--' [ argument ]* ] ;
    result = @[]
    while tokens.current != nil:
        if tokens.current == "--":
            return result & @tokens.map_it(Pattern, argument(nil, val(it)))
        elif tokens.current.starts_with("--"):
            result.add(parse_long(tokens, options))
        elif tokens.current.starts_with("-") and tokens.current != "-":
            result.add(parse_shorts(tokens, options))
        elif options_first:
            return result & @tokens.map_it(Pattern, argument(nil, val(it)))
        else:
            result.add(argument(nil, val(tokens.move())))


proc parse_section(name: string, source: string): seq[string]

proc parse_defaults(doc: string): seq[Option] =
    result = @[]
    for ss in parse_section("options:", doc):
        # FIXME corner case "bla: options: --foo"
        var s = ss.partition(":").right  # get rid of "options:"
        var split = ("\n" & s).split_inc(re"\n[\ \t]*(-\S+?)")
        for i in 1 .. split.len div 2:
            var s = split[i*2-1] & split[i*2]
            if s.starts_with("-"):
                result.add(option.option_parse(s))


proc parse_section(name: string, source: string): seq[string] =
    let pattern = re(r"^([^\n]*" & name & r"[^\n]*\n?(?:[ \t].*?(?:\n|$))*)",
                     {reIgnoreCase, reMultiLine})
    @(source.find_all(pattern)).map_it(string, it.strip())


proc formal_usage(section: string): string =
    var section = section.partition(":").right  # drop "usage:"
    var pu = section.split()
    var pu0 = pu[0]
    pu.delete()
    "( " & pu.map_it(string, if it == pu0: ") | (" else: it).join(" ") & " )"


proc extras(help: bool, version: string, options: seq[Pattern], doc: string) =
    if help and options.any_it((it.name in ["-h", "--help"]) and it.value):
        echo(doc.strip())
        quit()
    elif version != nil and
      options.any_it(it.name == "--version" and it.value):
        echo(version)
        quit()


proc docopt_exc(doc: string, argv: seq[string], help: bool, version: string,
                options_first = false): Table[string, Value] =

    var argv = (if argv.is_nil: command_line_params() else: argv)
    
    var usage_sections = parse_section("usage:", doc)
    if usage_sections.len == 0:
        raise new_exception(DocoptLanguageError,
                            "\"usage:\" (case-insensitive) not found.")
    if usage_sections.len > 1:
        raise new_exception(DocoptLanguageError,
                            "More than one \"usage:\" (case-insensitive).")
    var docopt_exit = new_exception(DocoptExit, "")
    docopt_exit.usage = usage_sections[0]
    
    var options = parse_defaults(doc)
    var pattern = parse_pattern(formal_usage(docopt_exit.usage), options)
    
    var argvt = parse_argv(tokens(argv), options, options_first)
    var pattern_options = pattern.flat(["Option"]).deduplicate()
    for options_shortcut in pattern.flat(["OptionsShortcut"]):
        var doc_options = parse_defaults(doc).deduplicate()
        options_shortcut.children = doc_options.filter_it(
          it notin pattern_options).map_it(Pattern, Pattern(it))
    
    extras(help, version, argvt, doc)
    pattern.fix()
    var (matched, left, collected) = pattern.match(argvt)
    if matched and left.len == 0:  # better error message if left?
        result = init_table[string, Value]()
        for a in pattern.flat([]):
            result[a.name] = a.value
        for a in collected:
            result[a.name] = a.value
    else:
        raise docopt_exit


proc docopt*(doc: string, argv: seq[string] = nil, help = true,
             version: string = nil, options_first = false, quit = true
            ): Table[string, Value] =
    ## Parse `argv` based on command-line interface described in `doc`.
    ##
    ## `docopt` creates your command-line interface based on its
    ## description that you pass as `doc`. Such description can contain
    ## --options, <positional-argument>, commands, which could be
    ## [optional], (required), (mutually | exclusive) or repeated...
    ##
    ## Parameters
    ## ----------
    ## doc : str
    ##     Description of your command-line interface.
    ## argv : seq[string], optional
    ##     Argument vector to be parsed. sys.argv[1:] is used if not
    ##     provided.
    ## help : bool (default: true)
    ##     Set to false to disable automatic help on -h or --help
    ##     options.
    ## version : string
    ##     If passed, the string will be printed if --version is in
    ##     `argv`.
    ## options_first : bool (default: false)
    ##     Set to true to require options precede positional arguments,
    ##     i.e. to forbid options and positional arguments intermix.
    ## quit : bool (default: true)
    ##     Set to false to let this function raise DocoptExit instead
    ##     of printing usage and quitting the application.
    ##
    ## Returns
    ## -------
    ## args : Table[string, Value]
    ##     A dictionary, where keys are names of command-line elements
    ##     such as e.g. "--verbose" and "<path>", and values are the
    ##     parsed values of those elements.
    ##
    ## Example
    ## -------
    ## import tables, docopt
    ##
    ## let doc = """
    ## Usage:
    ##     my_program tcp <host> <port> [--timeout=<seconds>]
    ##     my_program serial <port> [--baud=<n>] [--timeout=<seconds>]
    ##     my_program (-h | --help | --version)
    ##
    ## Options:
    ##     -h, --help  Show this screen and exit.
    ##     --baud=<n>  Baudrate [default: 9600]
    ## """
    ## let argv = @["tcp", "127.0.0.1", "80", "--timeout", "30"]
    ## echo docopt(doc, argv)
    ##
    ## # {serial: false, <host>: "127.0.0.1", --help: false, --timeout: "30",
    ## # --baud: "9600", --version: false, tcp: true, <port>: "80"}
    ##
    ## See also
    ## --------
    ## Full documentation: http://docopt.org/
    if not quit:
        return docopt_exc(doc, argv, help, version, options_first)
    try:
        return docopt_exc(doc, argv, help, version, options_first)
    except DocoptExit:
        stderr.writeln((ref DocoptExit)(get_current_exception()).usage)
        quit()
