if (typeof module != 'undefined')
  exports = module.exports
  PEG = require('pegjs')
  fs = require('fs');
  exports.parse = parse =
    PEG.buildParser(fs.readFileSync('scheem.peg', 'utf-8')).parse
else
  exports = window
  exports.parse = parse = SCHEEM.parse

throwBadArity = (expr) ->
  [form, parts...] = expr;
  throw new Error(
    "#{printScheem(form)}: bad syntax (has #{parts.length} parts after the keyword) " +
    "in: #{printScheem expr}"
  )

theNullEnvironment =
  lookup: (symbol) ->
    throw new Error "reference to an identifier before its definition: #{symbol}"
  isDefined: (symbol) -> false
  set: (symbol) ->
    throw new Error "cannot set variable before its definition: #{symbol}"

class Environment
  constructor: (@parent) ->
    @frame = {}
  lookup: (symbol) ->
    if @frame[symbol]?
      @frame[symbol]
    else
      @parent.lookup(symbol)
  isDefined: (symbol) -> @frame[symbol]? || @parent.isDefined(symbol)
  set: (symbol, value) ->
    if @frame[symbol]?
      @frame[symbol] = value
    else
      @parent.set(symbol)
  define: (symbol, value) ->
    @frame[symbol] = value
  extend: () -> new Environment this
  extendWith: (frame) ->
    ret = new Environment this
    ret.frame = frame
    return ret

assertArity = (expr, requiredArity) ->
  throwBadArity(expr) unless (arity(expr) == requiredArity + 1)

specialForms =
  quote:
    checkSyntax: (expr) -> assertArity expr, 1
    evaluate: ([expr]) -> expr
  define:
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, val], env) ->
      addVar env, ident, _eval(val, env)
      return 0
  'set!':
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, val], env) ->
      unless canSet(env, ident)
        throw new Error "set!: cannot set variable before its definition: #{ident}"
      setVar env, ident, _eval(val, env)
      return 0
  'if':
    checkSyntax: (expr) -> assertArity expr, 3
    evaluate: ([test, ifClause, elseClause], env) ->
      testResult = _eval(test, env)
      if testResult == '#t' then _eval(ifClause, env)
      else if testResult = '#f' then _eval(elseClause, env)
      else
        throw new Error "#{printScheem test} must return a Boolean in " +
        "#{printScheem ['if', test, ifClause, elseClause]}"
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
        af[argl[i]] = val for val, i in args
        activationEnv = env.extendWith(af)
        retval = _eval(expr, activationEnv) for expr in body
        return retval
      func.arity = argl.length
      return func

functions =
  '+': (x, y) -> x + y
  '<': (x, y) -> if x < y then '#t' else '#f'
  '=': (x, y) -> if x == y then '#t' else '#f'
  cons: (h, t) -> [h, t...]
  car: (list) -> list[0]
  cdr: (list) -> list[1...]

func.key = key for key, func of functions

arity = (func) -> func.arity ? func.length

_apply = (func, exprs, env) ->
  if arity(func) > 0
    assertArity [func, exprs...], arity(func)

  func( (_eval(expr, env) for expr in exprs)... )


exports.theGlobalEnv = new Environment theNullEnvironment
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
  if env.constructor.name == Environment then env
  else
    theGlobalEnv.extendWith(env)

exports.evalScheem = evalScheem = (expr, env) -> _eval expr, fixupEnv(env)

_eval = (expr, env) ->
  if typeof expr == 'number' then return expr
  else if typeof expr == 'string'
    switch expr
      when '#t', '#f' then expr
      else lookup env, expr
  else if expr.length == 0 then []
  else if sf = specialForms[expr[0]]
    [key, exprs...] = expr
    sf.checkSyntax(expr) if sf.checkSyntax
    sf.evaluate(exprs, env)
  else
    _apply _eval(expr[0], env), expr[1...], env

exports.printScheem = printScheem = (expr) ->
  switch typeof expr
    when 'undefined' then "*undef*"
    when 'number', 'string' then "#{expr}"
    when 'true'
      if expr then '#t'
      else         '#f'
    else
      switch expr.constructor.name
        when 'Array'
          "(" +
          (printScheem(i) for i in expr).join(' ') +
          ")"
        when 'Function'
          expr.key ? '#<procedure>'
        else "unknown construct, punting to javascript: #{expr}"

exports.evalScheemString = evalScheemString = (src, env) ->
  evalScheem(parse(src), env)