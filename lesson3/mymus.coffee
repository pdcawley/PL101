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

$$.rep = rep = (count, expr) ->
  ret =
    tag: 'repeat'
    section: expr
    'count': count
  ret

$$.seq = seq = (lst) ->
  [expr, exprs...] = lst
  switch exprs.length
    when 0 then expr
    else
      tag: 'seq'
      left: expr
      right: seq exprs

$$.par = par = (lst) ->
  [expr, exprs...] = lst
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
    console.log input
    if expected
      assert.deepEqual parse(input, production), expected
    else
      assert.doesNotThrow () -> parse input, production

  assertBadParse = (input) ->
    console.log "BAD: '#{input}'"
    assert.throws () -> parse(input)

  assertParses 'a4[100]', note('a4', 100), 'note'
  assertParses 'b4[100]', note('b4', 100), 'note'
  assertParses 'A4[100]', note('a4', 100), 'note'

  assertParses '-[100]', rest(100), 'rest'

  assertParses 'a4[100]',          note('a4', 100),                      'passage'
  assertParses 'a4[100]-[100]',    seq([note('a4', 100), rest(100)]), 'passage'
  assertParses 'a4[100] -[100]',   seq([note('a4', 100), rest(100)]), 'passage'
  assertParses "a4[100]  -[100]",  seq([note('a4', 100), rest(100)]), 'passage'
  assertParses "a4[100] \n-[100]", seq([note('a4', 100), rest(100)]), 'passage'

  assertParses "a3[100]", null, 'atom'
  assertParses "-[100]", null, 'atom'

  assertParses "(a3[100]-[150])", seq([note('a3', 100), rest(150)]), 'phrase'
  assertParses "(a3[100])", note('a3', 100), 'phrase'
  assertParses "((a3[100]) -[150])", seq([note('a3', 100), rest(150)]), 'phrase'
  assertParses(
    "((a3[100] a3[100]) (-[10] -[10]))"
    seq([
      seq([note('a3', 100), note('a3', 100)])
      seq([rest(10), rest(10)])
    ])
    'phrase'
  )

  assertParses "a4[100] b4[100] (a4[100] -[50])"

  assertParses "3 * a4[100]", rep(3, note('a4', 100)), 'repetition'
  assertParses "3 * (a4[100])", rep(3, note('a4', 100)), 'repetition'
  assertParses "3 * (a4[100] b4[100])", rep(3, seq([note('a4', 100), note('b4', 100)])), 'repetition'

  assertParses(
    "( c3[100] | e3[100] | g3[100] )"
    par([note('c3', 100), note('e3', 100), note('g3', 100)])
  )

  assertParses(
    "3*(c3[100] | e3[100])"
    rep(3, par([note('c3', 100), note('e3', 100)]))
  )
  assertParses(
    "3(c3[100] | e3[100])"
    rep(3, par([note('c3', 100), note('e3', 100)]))
  )

  assertBadParse '2*3*a4[100]'
  assertBadParse '()'
  assertBadParse 'z[10]'
  assertBadParse 'a4[]'
  assertBadParse 'a4[-10]'
