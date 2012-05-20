if (typeof module != 'undefined')
  exports = module.exports
  PEG = require 'pegjs'
  fs = require 'fs'
  exports.parse = parse =
    PEG.buildParser(fs.readFileSync('tortoise.peg', 'utf-8')).parse
  Environment = require('env').Environment
else
  exports = window
  exports.parse = parse = TORT.parse

class Turtle
  constructor: (raphArgs...) ->
    @paper = Raphael(raphArgs...)
    @originx = @paper.width / 2
    @originy = @paper.height / 2
    @clear()
  clear: () ->
    @paper.clear()
    @x = @originx
    @y = @originy
    @angle = 90
    @pen = true
    @turtleimg = undefined
    @updateTurtle()
  updateTurtle: () ->
    if @turtleimg == undefined
      @turtleimg = @paper.image(
        "http://nathansuniversity.com/gfx/turtle2.png"
        0,0,64,64
      )
    @turtleimg.attr
      x: @x - 32
      y: @y - 32
      transform: "r#{-@angle}"
    @turtleimg.toFront()
  drawTo: (x,y) ->
    [x1, y1] = [@x, @y]
    params = "stroke-width": 4
    path = @paper.path(
      Raphael.format(
        "M{0},{1}L{2},{3}"
        x1, y1
        x,  y
      )
    ).attr(params)
  forward: (d) ->
    newx = @x + Math.cos(Raphael.rad(@angle)) * d
    newy = @y - Math.sin(Raphael.rad(@angle)) * d

    if @pen then this.drawTo newx, newy

    @x = newx
    @y = newy
    this.updateTurtle()
  right: (ang) ->
    @angle -= ang
    this.updateTurtle()
  left: (ang) ->
    @angle += ang
    this.updateTurtle()

init_env = (new Environment theNullEnvironment).extendWith
  '<': (x,y) -> x < y
  '>': (x,y) -> x > y
  '<=': (x,y) -> x <= y
  '>=': (x,y) -> x >= y
  '!=': (x,y) -> x != y
  '==': (x,y) -> x == y
  '+': (x,y) -> x + y
  '-': (x,y) -> x - y
  '*': (x,y) -> x * y
  '/': (x,y) -> x / y

add_binding = (env, key, value) -> env.define key, value
update = (env, key, value) -> env.set key, value
lookup = (env, key) -> env.lookup key

evalExpr = (expr, env) ->
  if typeof expr == 'number'
    expr
  else
    switch expr.tag
      when '<', '>', '<=', '>=', '==', '!=', '+', '-', '*', '/'
        _apply lookup(env, expr.tag), [expr.left, expr.right], env
      when 'call'
        _apply lookup(env, expr.name), expr.args, env
      when 'ident'
        lookup env, expr.name

_apply = (func, exprs, env) ->
  func.apply(
    null
    [ evalExpr expr, env for expr in exprs ]
  )

evalStatement = (stmt, env) ->
  switch stmt.tag
    when 'ignore' then evalExpr stmt.body, env
    when 'var'
      add_binding(env, stmt.name, 0)
      0
    when ':='
      update(
        env
        stmt.left
        evalExpr stmt.right env
      )
    when 'if'
      if evalExpr stmt.expr, env
        evalStatements stmt.body, env
    when 'repeat'
      val = evalStatements(stmt.body, env) for [1 .. evalExpr(stmt.expr, env)]
      return val
    when 'define'
      new_func = (args...) ->
        evalStatements(
          stmt.body
          env.extendWith stmt.args, args
        )
      add_binding env, stmt.name, new_func
      return 0

evalStatements = (body, env) ->
  val = evalStatement stmt, env for stmt in body
  return val

exports.TortoiseInterpreter = class TortoiseInterpreter
  constructor: (args...) ->
    if args.length > 0
      @turtle = new Turtle args...
    @env = init_env.extendWith
      forward: (d) => @turtle.forward d
      right: (a)   => @turtle.right a
      left: (a)    => @turtle.left a
  eval: (expr) -> evalStatements expr, @env, @turtle
  evalString: (string) ->
    this.eval parse string
  parse: (string) -> parse string
