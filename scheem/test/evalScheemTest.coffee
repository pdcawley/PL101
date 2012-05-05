if (typeof module != 'undefined')
  CHAI = require('chai')
  assert = CHAI.assert
  expect = CHAI.expect
  scheem = require('../scheem')
  evalScheem = scheem.evalScheem
  printScheem = scheem.printScheem
  evalScheemString = scheem.evalScheemString
  parse = scheem.parse
else
  assert = chai.assert
  expect = chai.expect
  evalScheem = window.evalScheem
  printScheem = window.printScheem
  evalScheemString = window.evalScheemString
  parse = window.parse

suite "Lambda", ->
  test "((lambda () 1)) -> 1", ->
    assert.evalsTo("((lambda () 1))", 1)
  test "((lambda (x) (+ x x)) 1)", ->
    assert.evalsTo( "((lambda (x) (+ x x)) 1)", 2 )
  test "(begin (define addN (lambda (n) (lambda (x) (+ x n)))) ((addN 2) 1)", ->
    assert.evalsTo(
      "(begin (define addN (lambda (n) (lambda (x) (+ x n)))) ((addN 2) 1))"
      3
    )

suite "Expressions", ->
  test "(= 1 1)", ->
    assert.deepEqual parse("(= 1 1)"), ['=', 1, 1]
    assert.equal evalScheemString("(= 1 1)", {}), '#t'
  test "(if (= 1 1) 'same 'different) -> 'same')", ->
    assert.deepEqual(
      parse("(if (= 1 1) 'same 'different)")
      ['if', ['=', 1,1], ['quote', 'same'], ['quote', 'different']]
    )
    assert.equal evalScheemString("(if (= 1 1) 'same 'different)", {}), "same"
  test "(+ a 1) {a:2} -> 3", ->
    assert.equal(evalScheemString('(+ a 1)', {a:2}), 3)
  test "(begin (define a 1) (define b 2) (if (< a b) (+ a b) (- a b)))", ->
    assert.equal(
      evalScheemString(
        "(begin (define a 1) (define b 2) (if (< a b) (+ a b) (- a b)))"
        {}
      )
      3
    )

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
        [ 'define', 'a', 2 ] ]
      this.env
    )
    assert.deepEqual this.env, {'a': 2}

  test "Two cmnds", ->
    evalScheem(
      [ 'begin'
        [ 'define', 'a', 2 ]
        [ 'define', 'b', 3 ]
      ]
      this.env
    )
    assert.deepEqual this.env, {'a': 2, 'b': 3}

  test "returns value of last expr", ->
    assert.deepEqual(
      evalScheem(
        [ 'begin'
          [ 'define', 'a', 2 ]
          [ 'define', 'b', 3 ]
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

    test "evalScheemString('(#{op} #{arg1} #{arg2})') -> #{res}", ->
      assert.equal(
        evalScheemString("(#{op} #{arg1} #{arg2})", {})
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
    test "evalString(#{printScheem(['cons', car, cdr])}) => #{printScheem(res)}", ->
      assert.deepEqual(
        evalScheemString(printScheem(['cons', car, cdr], {}))
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
        evalScheemString printScheem(['car', ['quote', input]]), {}
        car
      )
    test "#{printScheem ['cdr', ['quote', input]]} => #{printScheem cdr}", ->
      assert.deepEqual(
        evalScheemString printScheem(['cdr', ['quote', input]]), {}
        cdr
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
    [ cond, exp ] = expectation
    test "(if #{printScheem cond} 1 0) => #{exp}", ->
      env = {}
      res = evalScheemString(
        "(if #{printScheem cond} (define true 1) (define false 1))"
        env
      )
      assert.equal res, 0
      # Should only eval the selected expr
      if exp
        assert.equal env['true'], 1
        assert.ok !env.hasOwnProperty('false')
      else
        assert.equal env['else'], 1
        assert.ok !env.hasOwnProperty('true')

assert.evalsTo = (src, exp, env) ->
  env ?= {}
  assert.deepEqual(
    evalScheemString(src, env)
    exp
  )

delayedEval = (expr, env) ->
  env ?= {}
  -> evalScheemString(expr, env)

suite "Parse + Interpret", ->
  suite "Numerics", ->
    test "'5' -> 5", ->
      assert.equal evalScheemString("5", {}), 5
    test "'-5' -> -5", ->
      assert.equal evalScheemString("-5", {}), -5
    test "'+5' -> 5", ->
      assert.equal evalScheemString("+5", {}), 5
    test "'5.5' -> 5.5", ->
      assert.equal evalScheemString("5.5", {}), 5.5

  suite "Self-eval", ->
    test '#t', ->
      assert.equal evalScheemString('#t', {}), '#t'
    test '()', ->
      assert.evalsTo('()', [])

  suite "Quote", ->
    test "'quoted", ->
      assert.deepEqual evalScheemString("'quoted", {}), 'quoted'
    test "'(a b c)", ->
      assert.deepEqual evalScheemString("'(a b c)", {}), ['a', 'b', 'c']

  suite "Arithmetic", ->
    test "1", ->
      assert.equal evalScheemString("(+ 1 2)", {}), 3

  suite "Environment manipulation", ->
    suite "define", ->
      test "(define a 2) sets a", ->
        env = {}
        evalScheemString('(define a 2)', env)
        assert.equal env.a, 2
      test "Redefinition is ok...", ->
        assert.evalsTo "(begin (define a 2) (define a 3) a)", 3
      test "(define a 2 3) is invalid", ->
        expect(delayedEval "(define a 2 3)", {}).to.throw()

    suite "set!", ->
      test "an existing variable", ->
        assert.evalsTo("(begin (define a 1) (set! a 3) a)", 3)
      test "cannot set a nonexistent variable", ->
        expect(delayedEval "(set! a 3)", {}).to.throw('set!: cannot set variable before its definition: a')
      test "(set! a 2 3) is a syntax error when redefining a var", ->
        expect(delayedEval "(set! a 3 2)", {a:1}).to.throw(
          'set!: bad syntax (has 3 parts after the keyword) in: (set! a 3 2)'
        )
      test "(set! a 2 3) is a syntax error and when trying to add a new one", ->
        expect(delayedEval "(set! a 3 2)", {}).to.throw(
          'set!: bad syntax (has 3 parts after the keyword) in: (set! a 3 2)'
        )
