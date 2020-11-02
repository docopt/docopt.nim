import docopt, macros, strutils, sequtils, typetraits

macro runUserImplemented(x: typed, fallback: untyped): untyped =
  ## This macro takes a type from a generic and checks if there exists a
  ## callable named `to<type name>`. If such a callable exists it will call it.
  ## Otherwise it will output an error saying that the type is invalid.
  let typ = x.getType
  if typ.kind == nnkBracketExpr and typ[0].kind == nnkSym and $typ[0] == "typeDesc":
    let call = newIdentNode("to" & $typ[1])
    result = quote do:
      when declared(`call`):
        `call`(v)
      else:
        `fallback`
  else:
    # This shouldn't really ever happen when properly passed a type from a generic
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

proc discardable(b: bool): bool {.discardable.} =
  ## Wrapper proc to allow the boolean result of `dispatchProc` to be discarded
  b

proc deSym(x: NimNode): NimNode =
  ## Procedure to strip symbols from a tree, replacing them with idents. This
  ## is needed to be able to snip the arguments from a procedure implementation
  ## and place them as arguments in Nim 1.4.0
  result = x
  for i in 0..<result.len:
    if result[i].kind == nnkSym:
      result[i] = newIdentNode($result[i])
    elif result[i].len != 0:
      result[i] = deSym(result[i])

macro dispatchProc*(args: Table[string, Value], procedure: proc,
    conditions: varargs[string]): untyped =
  ## Generates code by examining the signature of `procedure`. It looks for
  ## boolean values matching `conditions` in the parsed arguments in `args` and
  ## if all conditions are true then arguments from `args` will be unpacked
  ## to match the types given in the signature of `procedure` and `procedure`
  ## will be called. If no conditions are parsed the name of `procedure` will
  ## be used as the the condition.
  # Generate a sequence of `and` statements with the conditions equaling true
  var check = newLit(true)
  for condition in conditions:
    check = nnkInfix.newTree(newIdentNode("and"), check, quote do:
      `args`[`condition`] == true)

  let
    procImpl = procedure.getImpl.deSym
    argIt = newIdentNode("argIt")
    setArguments = newIdentNode("setArguments")

  # If no conditions are passed, use the procedure name as the only condition.
  if conditions.len == 0:
    let name = procImpl[0].strVal
    check = quote do:
      `args`[`name`] == true

  # Builds four things:
  # argVariables: A `var` section that defines all the arguments
  # setArgs: A set of which arguments have been found in the parsed list
  # findArgs: The body of a loop that assignes the variables in `argVariables`
  #   and sets the field in `setArgs` based on the parsed arguments in `args`
  # call: The procedure call with all the values from the var section.
  var
    argVariables = nnkVarSection.newTree()
    setArgs = nnkBracket.newTree()
    findArgs = newStmtList()
    call = nnkCall.newTree(procImpl[0])
    i = 0
  # Position 3 in a procedure implementation is the arguments, but also the
  # return value. So we skip the return value and parse the rest of the
  # arguments.
  for arg in procImpl[3][1..^1]:
    argVariables.add arg
    # Arguments are defined as a list of identifiers, then the type and then
    # any default value. We are only interested in the identifiers, so we skip
    # the last two elements.
    for subArg in arg[0..^3]:
      setArgs.add newLit(false)
      let
        name = subArg
        nameStr = subArg.strVal
        kind = arg[^2]
      findArgs.add quote do:
        if `argIt`.strip(chars = {'<', '>', '-'}) == `nameStr`:
          `setArguments`[`i`] = true
          `name` = `args`[`argIt`].to[:`kind`]()
      call.add name
      inc i

  # Define the variable for set arguments in the var section
  argVariables.add nnkIdentDefs.newTree(setArguments, newEmptyNode(), setArgs)

  # Stitches everything together
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
