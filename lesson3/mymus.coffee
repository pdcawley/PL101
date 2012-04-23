PEG = require "pegjs"
assert = require "assert"
fs = require "fs"

$$ = global.$$ = {}

$$.note = note = (p, d) ->
  tag: 'note',
  pitch: p
  dur: d

$$.rest = rest = (dur) ->
  tag: 'rest'
  duration: dur

$$.repeat = repeat = (count, expr) ->
  tag: 'repeat'
  section: expr
  'count': count

$$.phrase = phrase = (expr, exprs...) ->
  switch exprs.length
    when 0 then expr
    else
      tag: 'seq'
      left: expr
      right: phrase exprs

$$.par = par = (expr, exprs...) ->
  switch exprs.length
    when 0 then expr
    else
      tag: 'par',
      left: expr
      right: par exprs

fs.readFile 'mymus.peg', 'ascii', (err, data) ->
  parser = PEG.buildParser(data, {trackLineAndColumn: true})
  parse = parser.parse

  assertParses = (input, expected, production) ->
    assert.deepEqual parse(input, production || 'start'), expected

  assertBadParse = (input) ->
    assert.throws () -> parse(input)

  assertParses 'a4[100]', note('a4', 100), 'note'
  assertParses 'b4[100]', note('b4', 100), 'note'
  assertParses 'A4[100]', note('a4', 100), 'note'
