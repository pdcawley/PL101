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

# suite "Strings", ->
#   test "Simple strings", ->
#     assert.evalsTo('"a-string"', "a-string")

assert.evalsTo = (src, exp, env) ->
  env ?= {}
  assert.deepEqual(
    evalScheemString(src, env)
    exp
  )

delayedEval = (expr, env) ->
  env ?= {}
  -> evalScheemString(expr, env)

testEval = (expr, res, env) ->
  test "#{expr} -> #{printScheem res}", ->
    assert.evalsTo expr, res, env ? {}


__ = (string) ->
  tokenType: 'symbol'
  value: string

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
    assert.deepEqual parse("(= 1 1)"), [__('='), 1, 1]
    assert.equal evalScheemString("(= 1 1)", {}), true
  test "(if (= 1 1) \"same\" \"different\") -> 'same')", ->
    assert.equal evalScheemString("(if (= 1 1) \"same\" \"different\")", {}), "same"
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

suite 'Defining Variables', ->
  test 'a number', ->
    assert.evalsTo "(begin (define a-num 3) a-num)", 3
  test 'an atom', ->
    assert.evalsTo "(begin (define a-symbol 'dog) a-symbol)", __('dog')
  test 'a list', ->
    assert.evalsTo "(begin (define a-list '(1 2 3)) a-list)", [1,2,3]

suite 'Accessing variables', ->
  test 'an existing variable can be looked up', ->
    assert.evalsTo "a", 99, {a:99}

suite 'Setting Variables', ->
  setup ->
    this.env = {'the-var': []}

  test 'a number', ->
    assert.evalsTo "(begin (set! the-var 3) the-var)", 3, this.env
  test 'an atom', ->
    assert.evalsTo "(begin (set! the-var 'dog) the-var)", __('dog'), this.env
  test 'an atom', ->
    assert.evalsTo "(begin (set! the-var '(1 2 3)) the-var)", [1,2,3], this.env

suite '"begin" evaluates its args in order returning the value of the last one', ->
  test "One entry", ->
    assert.evalsTo '(begin (+ 1 2))', 3
  test "Two forms", ->
    assert.evalsTo(
      """
      (begin
        (define a 1)
        (+ a 2))
      """
      3
    )
  test "Three forms, why not?", ->
    assert.evalsTo(
      """
      (begin
        (define a 1)
        (define b (+ a 1))
        (+ a b))
      """
      3
    )

suite "Comparison and equality", ->
  expectations = [
    ["(< 1 2)", true]
    ["(< 2 1)", false]
    ["(< 1 1)", false]
    ["(= 1 2)", false]
    ["(= 2 1)", false]
    ["(= 1 1)", true]
  ]

  for expectation in expectations
    [expr, val] = expectation
    test "#{expr} => #{printScheem val}", ->
      assert.evalsTo(expr, val)

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
    [[[__('quote'), __('a')], []], [__('a')]]
    [[1, ['quote', [2,3]]], [1,2,3]]
  ]

  testEval "(cons 1 ())", [1]
  testEval "(cons 'a ())", [__ 'a']
  testEval "(cons 1 (list 2 3))", [1,2,3]

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
    [ '#t',      true  ]
    [ '#f',      false ]
    [ "(= 1 1)", true ]
    [ "(= 1 0)", false ]
    [ "(< 1 1)", false ]
    [ "(< 1 0)", false ]
    [ "(< 0 1)", true ]
  ]

  for expectation in tests
    [ cond, exp ] = expectation
    test "(if #{cond} 1 0) => #{exp}", ->
      env = theGlobalEnv.extendWith({})
      res = evalScheemString(
        "(if #{printScheem cond} (define true 1) (define false 1))"
        env
      )
      assert.equal res, 0
      console.log env
      # Should only eval the selected expr
      if exp
        assert.equal env.lookup('true'), 1
        expect(-> env.lookup('false')).to.throw()
      else
        assert.equal env['else'], 1
        assert.ok !env.hasOwnProperty('true')

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
    testEval '#t', true
    testEval '()', []
    testEval '10', 10
    suite "Strings", ->
      testEval '"String"', 'String'
      testEval '"Embedded \\"string\\""', 'Embedded "string"'

  suite "Quote", ->
    testEval "'quoted", __('quoted')
    testEval "'(a b c)", [__('a'), __('b'), __('c')]

  suite "Arithmetic", ->
    test "1", ->
      assert.equal evalScheemString("(+ 1 2)", {}), 3

  suite "Environment manipulation", ->
    suite "define", ->
      test "(define a 2) sets a", ->
        env = theGlobalEnv.extendWith({})
        evalScheemString('(define a 2)', env)
        assert.equal env.lookup('a'), 2
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
