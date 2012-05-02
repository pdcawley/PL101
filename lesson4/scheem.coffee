evlist = (exprs, env) ->
  ret = []
  for expr in exprs
    ret = evalScheem expr, env
  return ret

evalScheem = (expr, env) ->
  if typeof expr == 'number' then return expr
  if typeof expr == 'string' then return env[expr]
  switch expr[0]
    when '+'
      return(
        evalScheem(expr[1], env) +
        evalScheem(expr[2], env)
      )
    when 'quote' then return expr[1]
    when 'set!', 'define'
      env[expr[1]] = evalScheem expr[2], env
      return 0
    when 'begin'
      evlist expr[1..], env
    when '<'
      lt = evalScheem(expr[1], env) < evalScheem(expr[2], env)
      if lt then '#t'
      else '#f'
    when '='
      eq = evalScheem(expr[1], env) == evalScheem(expr[2], env)
      if eq then '#t'
      else '#f'
    when 'cons'
      car = evalScheem expr[1], env
      cdr = evalScheem expr[2], env
      [car, cdr...]
    when 'car'
      evalScheem(expr[1], env)[0]
    when 'cdr'
      evalScheem(expr[1], env)[1..-1]
    when 'if'
      if evalScheem(expr[1], env) == '#t'
        evalScheem expr[2], env
      else
        evalScheem expr[3], env

printScheem = (expr) ->
  switch typeof expr
    when 'number', 'string' then "#{expr}"
    when 'true'
      if expr then '#t'
      else         '#f'
    else
      "(" +
      (printScheem(i) for i in expr).join(' ') +
      ")"




if (typeof module != 'undefined')
  module.exports.evalScheem = evalScheem
  module.exports.printScheem = printScheem
else
  window.evalScheem = evalScheem
  window.printScheem = printScheem
