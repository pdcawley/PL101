theNullEnvironment =
  lookup: (symbol) ->
    throw new Error "Reference to an identifier before its definition: #{symbol}"
  isDefined: (symbol) -> false
  set: (symbol, val) ->
    throw new Error "Cannot set variable #{symbol} before its definition."

class Environment
  constructor: (@parent, @frame) ->
    @frame ?= {}
  lookup: (symbol) ->
    @frame[symbol] ? @parent.lookup(symbol)
  isDefined: (symbol) ->
    symbol of @frame or @parent.isDefined(symbol)
  set: (symbol, value) ->
    if symbol of @frame
      @frame[symbol] = value
    else
      @parent.set symbol, value
  define: (symbol, value) ->
    @frame[symbol] = value
  extend: () -> new Environment this
  extendWith: (frame, vals) ->
    if vals?
      nframe = {}
      for i, name of frame
        nframe[name] = vals[i]
    else
      nframe = frame
    ret = new Environment this, nframe

if typeof module != 'undefined'
  module.exports.Environment = Environment
