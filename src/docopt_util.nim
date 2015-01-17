# Copyright (C) 2015 Oleh Prypin <blaxpirit@gmail.com>
# Licensed under terms of MIT license (see LICENSE)


import re, sequtils, strutils


template any_it*(lst, pred: expr): expr =
    var result = false
    for it {.inject.} in lst.items:
        if pred:
            result = true
            break
    result


proc count*[T](s: seq[T], it: T): int =
    result = 0
    for x in s:
        if x == it:
            result += 1


iterator split_inc*(s: string, sep: Regex): string =
    var start = 0
    while true:
        var matches: seq[tuple[first, last: int]] = new_seq_with(20, (-1, -1))
        var (first, last) = s.find_bounds(sep, matches, start)
        if first < 0: break
        yield s.substr(start, <first)
        for a, b in matches.items:
            if a < 0: break
            yield s.substr(a, b)
        start = last+(if first > last: 2 else: 1)
    yield s.substr(start, s.high)
proc split_inc*(s: string, sep: Regex): seq[string] =
    accumulate_result(split_inc(s, sep))


proc partition*(s, sep: string): tuple[left, sep, right: string] =
    assert sep != nil and sep != "" 
    let pos = s.find(sep)
    if pos < 0:
        (s, "", "")
    else:
        (s.substr(0, <pos), s.substr(pos, <pos+sep.len), s.substr(pos+sep.len))


proc lstrip*(s: string, c: char): string =
    result = s
    while result.starts_with($c):
        result = result.substr(1)


proc is_upper*(s: string): bool =
    s == s.to_upper()


proc sub*[T](s: seq[T], a, b: int): seq[T] =
    ## Items from `a` to `b` non-inclusive
    if a < b: s[a .. <b]
    else: @[]


converter to_bool*[T](s: openarray[T]): bool = s.len > 0

converter to_bool*[T](s: seq[T]): bool = not s.is_nil and s.len > 0

converter to_bool*(s: string): bool = s != nil and s.len > 0
