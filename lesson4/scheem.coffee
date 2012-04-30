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


if (typeof module != 'undefined')
  module.exports.evalScheem = evalScheem
else
  window.evalScheem = evalScheem
