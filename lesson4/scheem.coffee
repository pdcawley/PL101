evlist = (exprs, env) ->
  ret = []
  for expr in exprs
    ret = evalScheem expr, env
  return ret

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
    "#{form}: bad syntax (has #{parts.length} parts after the keyword) " +
    "in: #{printScheem expr}"
  )

assertArity = (expr, arity) ->
  throwBadArity(expr) unless expr.length == arity + 1

specialForms =
  quote:
    checkSyntax: (expr) -> assertArity expr, 1
    evaluate: ([expr]) -> expr
  define:
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, val], env) ->
      env[ident] = evalScheem(val, env)
      return 0
  'set!':
    checkSyntax: (expr) -> assertArity expr, 2
    evaluate: ([ident, val], env) ->
      unless env.hasOwnProperty(ident)
        throw new Error "set!: cannot set variable before its definition: #{ident}"
      env[ident] = evalScheem(val, env)
      return 0
  'if':
    checkSyntax: (expr) -> assertArity expr, 3
    evaluate: ([test, ifClause, elseClause], env) ->
      testResult = evalScheem(test, env)
      if testResult == '#t' then evalScheem(ifClause, env)
      else if testResult = '#f' then evalScheem(elseClause, env)
      else
        throw new Error "#{printScheem test} must return a Boolean in " +
        "#{printScheem ['if', test, ifClause, elseClause]}"

functions =
  '+': (x, y) -> x + y
  '<': (x, y) -> if x < y then '#t' else '#f'
  '=': (x, y) -> if x == y then '#t' else '#f'
  begin: (exprs...) -> exprs[exprs.length-1]
  cons: (h, t) -> [h, t...]
  car: (list) -> list[0]
  cdr: (list) -> list[1...]

func.key = key for key, func of functions

applyFunc = (func, exprs, env) ->
  if func.length > 0
    assertArity [func.key, exprs...], func.length

  func( (evalScheem(expr, env) for expr in exprs)... )

exports.evalScheem = evalScheem = (expr, env) ->
  if typeof expr == 'number' then return expr
  else if typeof expr == 'string'
    switch expr
      when '#t', '#f' then expr
      else env[expr]
  else if expr.length == 0 then []
  else if sf = specialForms[expr[0]]
    [key, exprs...] = expr
    sf.checkSyntax(expr) if sf.checkSyntax
    sf.evaluate(exprs, env)
  else if func = functions[expr[0]]
    applyFunc func, expr[1...], env
  else
    throw new Error "Don't know how to evaluate #{printScheem expr}"

exports.printScheem = printScheem = (expr) ->
  switch typeof expr
    when 'number', 'string' then "#{expr}"
    when 'true'
      if expr then '#t'
      else         '#f'
    else
      "(" +
      (printScheem(i) for i in expr).join(' ') +
      ")"

exports.evalScheemString = evalScheemString = (src, env) ->
  evalScheem(parse(src), env)
