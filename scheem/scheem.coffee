if (typeof module != 'undefined')
  _ = module.exports
  PEG = require('pegjs')
  fs = require('fs');
  _.parse = parse =
    PEG.buildParser(fs.readFileSync('scheem.peg', 'utf-8')).parse
else
  _ = window
  _.parse = parse = SCHEEM.parse

_.ScheemUtils = {}

thunk = (f, lst) ->
  tag: "thunk"
  func: f
  args: lst

thunkValue = (val) ->
  tag: "value"
  val: val

trampoline = (thk) ->
  while typeof thk == 'object' and thk.tag?
    switch thk.tag
      when 'value' then return thk.val
      when 'thunk'
        thk = thk.func((thk.args ? [])...)
  return thk

SU = _.ScheemUtils

throwBadArity = (expr) ->
  [form, parts...] = expr;
  throw new Error(
    "#{printScheem(form)}: bad syntax (has #{parts.length} parts after the keyword) " +
    "in: #{printScheem expr}"
  )

theNullEnvironment =
  lookup: (symbol) ->
    throw new Error "reference to an identifier before its definition: #{unintern symbol}"
  isDefined: (symbol) -> false
  set: (symbol) ->
    throw new Error "cannot set variable before its definition: #{unintern symbol}"

SU.unintern = unintern = (symbol) -> if isSymbol symbol then symbol.value else symbol
SU.intern = intern = (symbol) ->
  if isSymbol symbol then symbol
  else
    tokenType: 'symbol'
    value: symbol

class Environment
  constructor: (@parent) ->
    @frame = {}
  lookup: (symbol) ->
    key = unintern symbol
    if @frame[key]?
      @frame[key]
    else
      @parent.lookup(key)
  isDefined: (symbol) ->
    key = unintern symbol
    @frame[key]? || @parent.isDefined(key)
  set: (symbol, value) ->
    key = unintern symbol
    if @frame[key]?
      @frame[key] = value
    else
      @parent.set(key, value)
  define: (symbol, value) ->
    @frame[unintern symbol] = value
  extend: () -> new Environment this
  extendWith: (frame) ->
    ret = new Environment this
    normedFrame = {}
    for key, value of frame
      normedFrame[unintern key] = value
    ret.frame = normedFrame
    return ret

assertArity = (expr, requiredArity) ->
  throwBadArity(expr) unless (arity(expr) == requiredArity + 1)

thunk_eval = (expr, env, cont) ->
  thunk _eval, [expr, env, cont]

eval_body = (exprs, env, cont) ->
  thunkLoop = (expr, rest...) ->
    if rest.length
      thunk_eval expr, env, ->
        thunk thunkLoop, rest
    else
      thunk_eval expr, env, (res) ->
        thunk cont, [res]
  thunkLoop exprs...

specialForms =
  quote:
    checkSyntax: (expr) -> assertArity expr, 1
    evaluate: (expr, env, cont) ->
      thunk cont, expr
  define:
    checkSyntax: (expr) ->
      unless expr[1].constructor.name == 'Array'
        assertArity expr, 2
    evaluate: (exprs, env, cont) ->
      if exprs[0].constructor.name == 'Array'
        [[ident, argl...], body...] = exprs
        thunk _eval, [
          ['lambda', argl, body...]
          env
          (func) ->
            func.key = unintern ident
            addVar env, ident, func
            thunk cont, [0]
        ]
      else
        thunk_eval exprs[1], env, (val) ->
          addVar env, exprs[0], val
          thunk cont, [0]
  'set!':
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, expr], env, cont) ->
      unless canSet(env, ident)
        throw new Error "set!: cannot set variable before its definition: #{unintern ident}"
      thunk _eval, [
        expr, env, (val) ->
          setVar env, ident, val
          thunk cont, [0]
      ]
  'if':
    checkSyntax: (expr) -> assertArity expr, 3
    evaluate: ([test, ifClause, elseClause], env, cont) ->
      thunk _eval, [
        test, env, (testResult) ->
          if testResult
            thunk _eval, [ifClause, env, cont]
          else
            thunk _eval, [elseClause, env, cont]
      ]
  'or':
    evaluate: (exprs, env, cont) ->
      thunkLoop = (expr, rest...) ->
        if expr?
          thunk_eval expr, env, (ret) ->
            if ret then thunk cont, [ret]
            else
              thunk thunkLoop, rest
        else
          thunk cont, [false]
      thunk thunkLoop, exprs
  'and':
    evaluate: (exprs, env, cont) ->
      thunkLoop = (expr, rest...) ->
        if expr?
          thunk_eval expr, env, (res) ->
            if res
              thunk thunkLoop, rest
            else
              thunk cont, [false]
        else
          thunk cont, [true]
      thunkLoop exprs...
  'begin':
    evaluate: (exprs, env, cont) -> eval_body exprs, env, cont
  'lambda':
    checkSyntax: (expr) ->
      unless expr[1].constructor.name == 'Array'
        throw new Error "lambda: bad args in: #{expr}"
      unless expr.length > 2
        throw new Error "lambda: missing body in #{expr}"
    evaluate: (expr, env, cont) ->
      [argl, body...] = expr
      func = (args, cont) ->
        af = {};
        af[argl[i].value] = val for val, i in args
        activationEnv = env.extendWith(af)
        eval_body body, activationEnv, cont
      func.arity = argl.length
      thunk cont, [func]
  'cond':
    evaluate: (exprs, env, cont) ->
      thunkLoop = (clause, rest...) ->
        if clause?
          [cond, body...] = clause
          isElseClause = isSymbol(cond) && unintern(cond) == 'else'
          if isElseClause
            eval_body body, env, cont
          else
            eval_thunk clause, env, (res) ->
              if res then eval_body body, env, cont
              else
                thunk thunkLoop, rest
        else
          throw new Error "Reached the end of the clauses and nothing came true in: " +
            printScheem [ 'cond', exprs... ]

SU.addSpecialForm = addSpecialForm = (name, generator) ->
  specialForms[name] = generator _eval

functions =
  '+': (args...) -> r = 0; r += n for n in args; r
  '-': (x, ys...) -> r = x; r -= y for y in ys; r
  '*': (args...) -> r = 1; r *= n for n in args; r
  '/': (x, ys...) ->
    if ys.length
      r = x
      r /= y for y in ys;
      r
    else
      1 / x
  'append': (list, lists...) -> list.concat(lists...)
  'list': (list...) -> list
  'reverse': (list) -> list.reverse()
  '<': (x, y) -> x < y
  '>': (x, y) -> x > y
  '<=': (x, y) -> x <= y
  '>=': (x, y) -> x >= y
  '=': (x, y) ->
    if isSymbol(x) and isSymbol(y)
      unintern(x) == unintern(y)
    else
      x == y
  'not': (x) -> not x
  'number?': (n) -> typeof(n) == 'number'
  'string?': (s) -> typeof(s) == 'string'
  'pair?': (l) -> l.constructor.name == 'Array' and l.length > 0
  'null?': (l) -> l.constructor.name == 'Array' and l.length == 0
  cons: (h, t) -> [h, t...]
  car: (list) -> list[0]
  caar: (list) -> list[0][0]
  cadr: (list) -> list[1...][0]
  cdar: (list) -> list[0][1...]
  cddr: (list) -> list[1...][1...]
  caaar: (list) -> list[0][0][0]
  caadr: (list) -> list[1...][0][0]
  cadar: (list) -> list[0][1...][0]
  cdaar: (list) -> list[0][0][1...]
  caddr: (list) -> list[1...][1...][0]
  cdadr: (list) -> list[1...][0][1...]
  cddar: (list) -> list[0][1...][1...]
  cdddr: (list) -> list[1...][1...][1...]
  cdr: (list) -> list[1...]
  nth: (n, list) -> list[n - 1]
  'set-car!': (list, newcar) -> list[0] = newcar
  'set-cdr!': (list, newcdr) -> list[1...] = newcdr
  alert: (arg) ->
    (alert ? console.log)(unintern arg)
    arg
  intern: (str) -> intern str
  unintern: (sym) -> unintern sym
  error: (args...) ->
    throw new Error (unintern arg for arg in args).join('')

thunkedFuncs = {}
for name, func of functions
  func = (->
    unThunked = func
    thunked = (args, cont) ->
      thunk cont, [unThunked args...]
    thunked.arity = unThunked.arity ? unThunked.length
    thunked
  )()
  func.key = name
  thunkedFuncs[name] = func

arity = (func) -> func.arity ? func.length

_.theGlobalEnv = theGlobalEnv = new Environment theNullEnvironment
theGlobalEnv.frame = thunkedFuncs

# lookup = (env, symbol) -> env[symbol]
# canSet = (env, symbol) -> env.hasOwnProperty(symbol)
# setVar = (env, symbol, value) -> env[symbol] = value
# addVar = (env, symbol, value) -> env[symbol] = value

lookup = (env, symbol) -> env.lookup(symbol)
canSet = (env, symbol) -> env.isDefined(symbol)
setVar = (env, symbol, value) -> env.set(symbol, value)
addVar = (env, symbol, value) -> env.define(symbol, value)

fixupEnv = (env) ->
  return theGlobalEnv unless env?
  if env.constructor.name == 'Environment' then env
  else
    theGlobalEnv.extendWith(env)

_.evalScheem = evalScheem = (expr, env) ->
  trampoline thunk_eval expr, fixupEnv(env), thunkValue

SU.isSymbol = isSymbol = (expr) ->
  expr?.constructor?.name == 'Object' &&
  expr?.tokenType == 'symbol'

make_c_splat_r = (expr, env) ->
  env ?= theGlobalEnv
  actions = expr.match(/c([ad]+)/)[1].split('').reverse()
  env.define(
    expr
    (l) ->
      ret = l
      for action in actions
        ret = if action == 'a' then ret[0] else ret[1...]
      return ret
  )

_eval = (expr, env, cont) ->
  if typeof expr == 'number'
    thunk cont, [expr]
  else if typeof expr == 'string'
    thunk cont, [expr]
  else if isSymbol expr
    switch expr.value
      when '#t' then thunk cont, [true]
      when '#f' then thunk cont, [false]
      else
        if expr.value.match(/^c[ad]+r/) and not env.isDefined expr
          thunk cont, [ make_c_splat_r unintern expr ]
        thunk cont, [lookup env, expr]
  else if expr.length == 0 then thunk cont, [[]]
  else if sf = specialForms[unintern expr[0]]
    [key, exprs...] = expr
    sf.checkSyntax(expr) if sf.checkSyntax
    thunk sf.evaluate, [exprs, env, cont]
  else
    thunk_eval expr[0], env, (func) ->
      thunk _apply, [func, expr[1...], env, cont]

_apply = (func, exprs, env, cont) ->
  if arity(func) > 0
    assertArity [func, exprs...], arity(func)
  args = []
  thunkLoop = (expr, rest...) ->
    if expr?
      thunk_eval expr, env, (val) ->
        args.push val
        thunk thunkLoop, rest
    else
      thunk func, [args, cont]
  thunk thunkLoop, exprs

_.printScheem = printScheem = (expr) ->
  switch typeof expr
    when 'undefined' then "*undef*"
    when 'number' then "#{expr}"
    when 'string' then "\"#{expr}\""
    when 'boolean'
      if expr then '#t'
      else         '#f'
    else
      if isSymbol(expr)
        return expr.value
      switch expr.constructor.name
        when 'Array'
          if unintern expr[0] == 'quote'
            return "'" + printScheem expr[1]
          "(" +
          (printScheem(i) for i in expr).join(' ') +
          ")"
        when 'Function'
          expr.value ? expr.key ? '#<procedure>'
        else "unknown construct, punting to javascript: #{expr}"

SU.isSpecialForm = (symbol) -> specialForms[unintern symbol]
SU.isBound = (symbol, env) -> env.isDefined(symbol)

_.evalScheemString = evalScheemString = (src, env) ->
  evalScheem(parse(src), env)

_.evalScheemProgram = evalScheemProgram = (src, env) ->
  programEnv = fixupEnv env
  exprs = parse src, 'program'
  results = []
  thunkLoop = (expr, rest...) ->
    if expr?
      eval_thunk expr, programEnv, (val) ->
        results.push val
        thunk thunkLoop, rest
    else
      thunkValue(
        allResults: results
        result: results[results.length-1]
        env: programEnv
        parseTree:exprs
      )
