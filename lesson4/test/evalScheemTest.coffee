if (typeof module != 'undefined')
  assert = require('chai').assert
  evalScheem = require('../scheem').evalScheem
else
  assert = chai.assert
  evalScheem = window.evalScheem

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
