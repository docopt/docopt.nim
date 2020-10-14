import docopt, macros, strutils, sequtils, typetraits

macro runUserImplemented(x: typed, fallback: untyped): untyped =
  let typ = x.getType
  if typ.kind == nnkBracketExpr and typ[0].kind == nnkSym and $typ[0] == "typeDesc":
    let call = newIdentNode("to" & $typ[1])
    result = quote do:
      when declared(`call`):
        `call`(v)
      else:
        `fallback`
  else:
    result = fallback

proc to[T](v: Value): T =
  when T is SomeInteger:
    T(parseInt($v))
  elif T is bool:
    v.toBool
  elif T is string:
    $v
  elif T is seq:
    @v
  else:
    runUserImplemented(T):
      {.error: "Invalid type \"" & $T & "\" in signature of dispatched procedure".}

proc discardable(b: bool): bool {.discardable.} = b

macro dispatchProc*(args: Table[string, Value], procedure: proc, conditions: varargs[string]): untyped =
  var check = newLit(true)
  for condition in conditions:
    check = nnkInfix.newTree(newIdentNode("and"), check, quote do:
      `args`[`condition`] == true)
  let
    procImpl = procedure.getImpl
    argIt = newIdentNode("argIt")
    setArguments = newIdentNode("setArguments")
  if conditions.len == 0:
    let name = $procImpl[0]
    check = quote do:
      `args`[`name`] == true
  var
    argVariables = nnkVarSection.newTree()
    setArgs = nnkBracket.newTree()
    findArgs = newStmtList()
    call = nnkCall.newTree(procImpl[0])
    i = 0
  for arg in procImpl[3][1..^1]:
    argVariables.add arg
    for subArg in arg[0..^3]:
      setArgs.add newLit(false)
      let
        name = subArg
        nameStr = $subArg
        kind = arg[^2]
      findArgs.add quote do:
        if `argIt`.strip(chars = {'<', '>', '-'}) == `nameStr`:
          `setArguments`[`i`] = true
          `name` = `args`[`argIt`].to[:`kind`]()
      call.add name
      inc i
  argVariables.add nnkIdentDefs.newTree(setArguments, newEmptyNode(), setArgs)
  result = quote do:
    if `check`:
      `argVariables`
      for `argIt` in `args`.keys:
        `findArgs`
      if `setArguments`.allIt(it == true):
        `call`
      discardable true
    else:
      discardable false
