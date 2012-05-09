if (typeof module != 'undefined')
  exports = module.exports
  PEG = require('pegjs')
  fs = require('fs');
  exports.parse = parse =
    PEG.buildParser(fs.readFileSync('scheem.peg', 'utf-8')).parse
else
  exports = window
  exports.parse = parse = SCHEEM.parse

exports.ScheemUtils = {}

SU = exports.ScheemUtils

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

specialForms =
  quote:
    checkSyntax: (expr) -> assertArity expr, 1
    evaluate: ([expr]) -> expr
  define:
    checkSyntax: (expr) ->
      unless expr[1].constructor.name == 'Array'
        assertArity expr, 2
    evaluate: (exprs, env) ->
      if exprs[0].constructor.name == 'Array'
        [[ident, argl...], body...] = exprs
        func = _eval(['lambda', argl, body...], env)
        func.key = unintern ident
        addVar env, ident, func
      else
        addVar env, exprs[0], _eval(exprs[1], env)
      return 0
  'set!':
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, val], env) ->
      unless canSet(env, ident)
        throw new Error "set!: cannot set variable before its definition: #{unintern ident}"
      setVar env, ident, _eval(val, env)
      return 0
  'if':
    checkSyntax: (expr) -> assertArity expr, 3
    evaluate: ([test, ifClause, elseClause], env) ->
      testResult = _eval(test, env)
      if testResult then _eval(ifClause, env)
      else _eval(elseClause, env)
  'or':
    evaluate: (exprs, env) ->
      for expr in exprs
        ret = _eval expr, env
        return ret if ret
  'and':
    evaluate: (exprs, env) ->
      ret = true
      for expr in exprs
        ret = _eval expr, env
        return false unless ret
      return ret
  'begin':
    evaluate: (exprs, env) ->
      retval = _eval(expr, env) for expr in exprs
      return retval
  'lambda':
    checkSyntax: (expr) ->
      unless expr[1].constructor.name == 'Array'
        throw new Error "lambda: bad args in: #{expr}"
      unless expr.length > 2
        throw new Error "lambda: missing body in #{expr}"
    evaluate: (expr, env) ->
      [argl, body...] = expr
      func = (args...) ->
        af = {};
        af[argl[i].value] = val for val, i in args
        activationEnv = env.extendWith(af)
        retval = _eval(expr, activationEnv) for expr in body
        return retval
      func.arity = argl.length
      return func
  'cond':
    evaluate: (exprs, env) ->
      for clause in exprs
        [cond, body...] = clause
        isElseClause = isSymbol(cond) && unintern(cond) == 'else'
        if isElseClause || _eval(cond, env)
          return _eval [ 'begin', body... ], env
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

func.key = key for key, func of functions

arity = (func) -> func.arity ? func.length

_apply = (func, exprs, env) ->
  if arity(func) > 0
    assertArity [func, exprs...], arity(func)

  func( (_eval(expr, env) for expr in exprs)... )


exports.theGlobalEnv = theGlobalEnv = new Environment theNullEnvironment
theGlobalEnv.frame = functions

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

exports.evalScheem = evalScheem = (expr, env) -> _eval expr, fixupEnv(env)

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

_eval = (expr, env) ->
  if typeof expr == 'number' then return expr
  else if typeof expr == 'string' then return expr
  else if isSymbol expr
    switch expr.value
      when '#t' then true
      when '#f' then false
      else
        if expr.value.match(/^c[ad]+r/) and not env.isDefined expr
          make_c_splat_r unintern expr
        lookup env, expr
  else if expr.length == 0 then []
  else if sf = specialForms[unintern expr[0]]
    [key, exprs...] = expr
    sf.checkSyntax(expr) if sf.checkSyntax
    sf.evaluate(exprs, env)
  else
    _apply _eval(expr[0], env), expr[1...], env

exports.printScheem = printScheem = (expr) ->
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

SU.isSpecialForm = (symbol) ->
  specialForms[unintern symbol] ? lookup(symbol)?.isSpecialForm
SU.isBound = (symbol, env) -> env.isDefined(symbol)

exports.evalScheemString = evalScheemString = (src, env) ->
  evalScheem(parse(src), env)

exports.evalScheemProgram = evalScheemProgram = (src, env) ->
  programEnv = fixupEnv env
  exprs = parse src, 'program'
  results = (_eval expr, programEnv for expr in exprs)
  return(
    allResults: results
    result: results[results.length - 1]
    env: programEnv
    parseTree: exprs
  )
