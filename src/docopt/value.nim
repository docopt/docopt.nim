# Copyright (C) 2015 Oleh Prypin <blaxpirit@gmail.com>
# Licensed under terms of MIT license (see LICENSE)


import strutils
import util


type
    ValueKind* = enum
        vkNone, ## No value
        vkBool, ## A boolean
        vkInt,  ## An integer
        vkStr,  ## A string
        vkList  ## A list of strings
    Value* = object  ## docopt variant type
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
        of vkStr: v.str_v.len > 0
        of vkList: v.list_v.len > 0

proc len*(v: Value): int =
    ## Return the integer of a vkInt Value
    ## or the length of the seq of a vkList value.
    ## It is an error to use it on other kinds of Values.
    if v.kind == vkInt: v.int_v
    else: v.list_v.len

proc `@`*(v: Value): seq[string] =
    ## Return the seq of a vkList Value.
    ## It is an error to use it on other kinds of Values.
    v.list_v

proc `[]`*(v: Value, i: int): string =
    ## Return the i-th item of the seq of a vkList Value.
    ## It is an error to use it on other kinds of Values.
    v.list_v[i]

iterator items*(v: Value): string =
    ## Iterate over the seq of a vkList Value.
    ## It is an error to use it on other kinds of Values.
    for val in v.list_v:
        yield val

iterator pairs*(v: Value): tuple[key: int, val: string] =
    ## Iterate over the seq of a vkList Value, yielding ``(index, v[index])``
    ## pairs.
    ## It is an error to use it on other kinds of Values.
    for key, val in v.list_v:
        yield (key: key, val: val)

proc str(s: string): string =
    "\"" & s.replace("\"", "\\\"") & "\""

proc str[T](s: seq[T]): string =
    "[" & s.map_it(string, it.str).join(", ") & "]"

proc str(v: Value): string =
    case v.kind
        of vkNone: "nil"
        of vkStr: v.str_v.str
        of vkInt: $v.int_v
        of vkBool: $v.bool_v
        of vkList: v.list_v.str

proc `$`*(v: Value): string =
    ## Return the string of a vkStr Value,
    ## or the item of a vkList Value, if there is exactly one,
    ## or a string representation of any other kind of Value.
    if v.kind == vkStr:
        v.str_v
    elif v.kind == vkList and v.list_v.len == 1:
        v.list_v[0]
    else: v.str

proc `==`*(a, b: Value): bool {.gcsafe.} =
    a.kind == b.kind and a.str == b.str


proc val(): Value = Value(kind: vkNone)
proc val(v: bool): Value = Value(kind: vkBool, bool_v: v)
proc val(v: int): Value = Value(kind: vkInt, int_v: v)
proc val(v: string): Value = Value(kind: vkStr, str_v: v)
proc val(v: seq[string]): Value = Value(kind: vkList, list_v: v)
