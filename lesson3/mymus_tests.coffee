assert = require "assert"
MUS = require "./mymus"

note = MUS.note
seq  = MUS.seq
rest = MUS.rest
par  = MUS.par
rep  = MUS.rep

MUS.withParser (parser) ->
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

  assertParses 'a4[100]',          note('a4', 100),                   'passage'
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

  assertParses "a3:4",  note('a3', 500)
  assertParses "a3:8",  note('a3', 250)
  assertParses "a3:8.", note('a3', 3 * 250 / 2)
  assertParses "a3",    note('a3', 500)
  assertParses "a3.",   note('a3', 3 * 500 / 2)

  assertParses "-:4", rest(500)
  assertParses "-:8", rest(250)
  assertParses "-:8.", rest(3 * 250 / 2)
  assertParses "-",   rest(500)
  assertParses "-.",  rest(3 * 500 / 2)

  assertParses "a3>c3", seq(note('a3', 750), note('c3', 250))
  assertParses "a3 > c3", seq(note('a3', 750), note('c3', 250))
  assertParses "a4:8>c3", seq(note('a3' , 3*250/2), note('c3', 250/2))

  assertParses(
    "3{a3 b3 c3}[300]"
    seq(
      note 'a3', 200
      note 'b3', 200
      note 'c3', 200
    )
  )

  MUS.bpm = 100

  assertParses(
    "3{g4g4g4}:8"
    seq(
      note 'g4', 200
      note 'g4', 200
      note 'g4', 200
    )
  )

  assertParses "f#4", note('f#4', 600)
  assertParses "(3{g4g4g4}:8g4 3{g4g4g4}:8g4:8>d5)"
  assertParses "(b5:8>g4b4:8>d5 g5:8>d5b4:8>g4)"
  assertParses "(3{d4d4d4}:8d4 3{d4d4d4}:8d4:8>a4)"
  assertParses "(f#4:8>d4f#4:8>a4) c5:8>a4f#4:8>a5"



  assertBadParse '2*3*a4[100]'
  assertBadParse '()'
  assertBadParse 'z[10]'
  assertBadParse 'a4[]'
  assertBadParse 'a4[-10]'
