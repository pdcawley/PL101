if (typeof module != 'undefined')
  assert = require('chai').assert
  scheem = requier('../scheem')
  evalScheem = scheem.evalScheem
  printScheem = scheem.printScheem
else
  assert = chai.assert
  evalScheem = window.evalScheem
  printScheem = window.printScheem

suite 'quote', ->
  test 'a number', ->
    assert.deepEqual(
      evalScheem ['quote', 3], {}
      3
    )
  test 'an atom', ->
    assert.deepEqual(
      evalScheem ['quote', 'dog'], {}
      'dog'
    )
  test 'a list', ->
    assert.deepEqual(
      evalScheem ['quote', [1,2,3]], {}
      [1,2,3]
    )

suite 'Numbers', ->
  test 'a number is itself', ->
    assert.deepEqual(
      evalScheem 3, {}
      3
    )

suite 'Setting Variables', ->
  setup ->
    this.env = {}

  test 'a number', ->
    assert.deepEqual(
      evalScheem ['set!', 'a-num', ['quote', 3]], this.env
      0
    )
    assert.deepEqual this.env, { "a-num": 3 }
  test 'an atom', ->
    assert.deepEqual(
      evalScheem ['set!', 'a-string', ['quote', 'dog']], this.env
      0
    )
    assert.deepEqual this.env, { "a-string": 'dog' }
  test 'a list', ->
    evalScheem ['set!', 'a-list', ['quote', [1,2,3]]], this.env
    assert.deepEqual this.env, {"a-list": [1,2,3]}

suite 'Accessing variables', ->
  test 'an existing variable can be looked up', ->
    assert.deepEqual(
      evalScheem('a', {a: 99})
      99
    )

suite 'Defining Variables', ->
  setup ->
    this.env = {}

  test 'a number', ->
    assert.deepEqual(
      evalScheem ['define', 'a-num', ['quote', 3]], this.env
      0
    )
    assert.deepEqual this.env, { "a-num": 3 }
  test 'an atom', ->
    assert.deepEqual(
      evalScheem ['define', 'a-string', ['quote', 'dog']], this.env
      0
    )
    assert.deepEqual this.env, { "a-string": 'dog' }
  test 'a list', ->
    evalScheem ['define', 'a-list', ['quote', [1,2,3]]], this.env
    assert.deepEqual this.env, {"a-list": [1,2,3]}

suite 'begin', ->
  setup ->
    this.env = {}

  test "One entry", ->
    evalScheem(
      [ 'begin'
        [ 'set!', 'a', 2 ] ]
      this.env
    )
    assert.deepEqual this.env, {'a': 2}

  test "Two cmnds", ->
    evalScheem(
      [ 'begin'
        [ 'set!', 'a', 2 ]
        [ 'set!', 'b', 3 ]
      ]
      this.env
    )
    assert.deepEqual this.env, {'a': 2, 'b': 3}

  test "returns value of last expr", ->
    assert.deepEqual(
      evalScheem(
        [ 'begin'
          [ 'set!', 'a', 2 ]
          [ 'set!', 'b', 3 ]
          [ '+', 'a', 'b']
        ]
        this.env
      )
      5
    )
    assert.deepEqual this.env, {'a': 2, 'b': 3}


suite "Comparison and equality", ->
  expectations = [
    ['<', 1, 2, '#t']
    ['<', 2, 1, '#f']
    ['<', 1, 1, '#f']
    ['=', 1, 2, '#f']
    ['=', 2, 1, '#f']
    ['=', 1, 1, '#t']
  ]

  for expectation in expectations
    [op, arg1, arg2, res] = expectation
    test "(#{op} #{arg1} #{arg2}) => #{res}", ->
      assert.equal(
        evalScheem expectation[0..2], {}
        res
      )


suite "printScheem", ->
  test "number", ->
    assert.equal printScheem(1), '1'
  test "atom", ->
    assert.equal printScheem('a'), 'a'
  test "[1,2] => (1 2)", ->
    assert.equal printScheem([1,2]), '(1 2)'

suite "Consing stuff up", ->
  table = [
    [[1, []], [1]]
    [[['quote', 'a'], []], ['a']]
    [[1, ['quote', [2,3]]], [1,2,3]]
  ]

  for expectation in table
    [[car, cdr], res] = expectation
    test "#{printScheem(['cons', car, cdr])} => #{printScheem(res)}", ->
      assert.deepEqual(
        evalScheem ['cons', car, cdr], {}
        res
      )

suite "Car and cdr", ->
  table = [
    [[1,2,3], 1, [2,3]]
    [[1,2],   1, [2]]
    [[1],     1, []]
    [[[1], 2,3], [1], [2,3]]
  ]

  for expectation in table
    [input, car, cdr] = expectation
    test "#{printScheem ['car', ['quote', input]]} => #{printScheem car}", ->
      assert.deepEqual(
        evalScheem ['car', ['quote', input]], {}
        car
      )
    test "#{printScheem ['cdr', ['quote', input]]} => #{printScheem cdr}", ->
      assert.deepEqual(
        evalScheem ['cdr', ['quote', input]], {}
        cdr
      )

assert.evalsTo = (expr, expected, env) ->
  env ?= {}
  assert.deepEqual(
    evalScheem expr, env
    expected
  )


suite "If", ->
  tests = [
    [ '#t',       true  ]
    [ '#f',       false ]
    [ ['=', 1, 1], true ]
    [ ['=', 1, 0], false ]
    [ ['<', 1, 1], false ]
    [ ['<', 1, 0], false ]
    [ ['<', 0, 1], true ]
  ]

  for expectation in tests
    [ cond, res ] = expectation
    test "(if #{printScheem cond} 1 0) => #{res}", ->
      env = {}
      assert.evalsTo(
        [
          'if', cond
          ['set!', 'true', 1]
          ['set!', 'false', 1]
        ]
        0
        env
      )
      # Should only eval the selected expr
      if res
        assert.equal env['true'], 1
        assert.ok !env.hasOwnProperty('false')
      else
        assert.equal env['else'], 1
        assert.ok !env.hasOwnProperty('true')
