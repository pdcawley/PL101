if (typeof module != 'undefined')
  CHAI = require('chai')
  assert = CHAI.assert
  expect = CHAI.expect
  scheem = require('../scheem')
  evalScheem = scheem.evalScheem
  printScheem = scheem.printScheem
  evalScheemString = scheem.evalScheemString
  evalScheemProgram = scheem.evalScheemProgram
  theGlobalEnv = scheem.theGlobalEnv
  SU = scheem.ScheemUtils
  parse = scheem.parse
else
  assert = chai.assert
  expect = chai.expect
  evalScheem = window.evalScheem
  printScheem = window.printScheem
  evalScheemString = window.evalScheemString
  evalScheemProgram = window.evalScheemProgram
  SU = window.ScheemUtils
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

ok = (expr, env) ->
  testEval expr, true, env

check = (desc, forms...) ->
  suite desc, ->
    ok form for form in forms

SU.addSpecialForm 'suite', (_eval) ->
  evaluate: (exprs, outerEnv) ->
    [name, preamble, checks...] = exprs
    env = outerEnv.extendWith({})
    _eval(preamble, env)
    suite name, ->
      for check in checks
        assertion = SU.unintern check[0]
        innerEnv = env.extendWith({})
        if assertion == 'is'
          ((check, env) ->
            exp = _eval(check[2], env)
            test "#{printScheem check[1]} -> #{printScheem exp}", ->
              assert.deepEqual _eval(check[1], env), exp
          )(check, innerEnv)
        else if assertion == 'ok'
          ((check, env) ->
            test "(ok #{printScheem check[1]})", ->
              assert.ok _eval check[1], env
          )(check, env)
        else
          ((check, env) -> _eval check, env)(check, innerEnv)
      return

SU.addSpecialForm 'is', (_eval) ->
  evaluate: (exprs, outerEnv) ->
    env = outerEnv.extendWith({})
    expected = _eval exprs[2], env
    test "#{printScheem exprs[1]} -> #{printScheem expected}", ->
      assert.deepEqual _eval(exprs[1], env), expected

__ = (string) ->
  tokenType: 'symbol'
  value: string

evalScheemProgram '''
(suite "="
    #t
  (ok (= 1 1))
  (ok (= "foo" "foo"))
  (ok (= 'foo 'foo)))

(suite "Factorial/cond"
    (define (factorial n)
      (cond ((= 0 n) 1)
            (else (* n (factorial (- n 1))))))
  (is (factorial 0) 1)
  (is (factorial 10) (* 10 9 8 7 6 5 4 3 2 1)))

(suite "Environments inside scheem"
    #t
  (suite "Association Lists"
      (begin
        (define (assoc key list)
          "Lookup KEY in LIST"
          (cond ((null? list) ())
                ((= key (caar list)) (cadar list))
                (else (assoc key (cdr list)))))
        (define (make-assoc names values)
          (define (loop l n v)
            (if (null? n) l
              (loop (cons (list (car n) (car v)) l)
                    (cdr n)
                    (cdr v))))
          (loop () names values))
      )
    (is (assoc (quote foo) ()) ())
    (is (assoc (quote foo) (quote ((foo 1)))) 1)
    (is (assoc (quote foo) (quote ((bar 1) (baz 1)))) ())
    (is (assoc \'foo \'((bar 1) (foo 2))) 2)
    (is (make-assoc \'(a b c) \'(1 2 3))
        \'((c 3) (b 2) (a 1)))
    (suite "Build and associate"
        (define assocL
          (make-assoc
            \'(a b c d)
            (list 1 (lambda () \'b) \'c \'(a list))))
      (is (assoc \'a assocL) 1)
      (is ((assoc \'b assocL)) \'b)
      (is (assoc \'c assocL) \'c)
      (is (assoc \'d assocL) \'(a list)))
  ))
'''

check("Function definitions"
  "(begin
    (define add1 (lambda (n) (+ n 1)))
    #t)"
  "(begin (define add1 (lambda (n) (+ 1 n))) (= (add1 2) 3))"
  "(= ((lambda (n) (+ 1 n)) 2) 3)"
  "(begin
    (define compose (lambda (f g) (lambda (arg) (f (g arg)))))
    (= ((compose car cdr) (list 1 2 3)) 2))"
  "(begin
    (define it 99)
    (define shadow (lambda (arg) (define it (+ 27 arg)) it))
    (shadow 3)
    (if (= (shadow 3) 30)
      (= it 99)
      #f))"
  "(begin
    (define count 0)
    (define call-counter
      (lambda ()
        (set! count (+ count 1))
        count))
    (call-counter)
    (call-counter)
    (= count 2))"
  "(begin
    (define make-adder
      (lambda (n)
        (lambda (i) (+ n i))))
    (define add2 (make-adder 2))
    (= (add2 1) 3))"
)

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

suite "Supplied functions", ->
  suite 'null?', ->
    ok "(null? '())"
    ok "(not (null? '(1 2)))"
    ok '(not (null? "string"))'
    ok "(not (null? 10))"

  suite 'string?', ->
    ok '(string? "string")'
    ok '(not (string? \'symbol))'

  suite 'pair?', ->
    ok "(pair? (list 1 2 3))"
    ok "(pair? '(1))"
    ok "(not (pair? ()))"
    ok "(not (pair? 'atom))"
    ok "(not (pair? pair?))"
    ok "(not (pair? 10))"

  check(
    "number?"
    "(number? 10)"
    "(not (number? \"string\"))"
    "(not (number? 'a))"
    "(not (number? ()))"
    "(not (number? (list 1 2 3)))"
  )

  suite "list manipulation", ->
    testEval "(list 1 2 3)",                        [1,2,3]
    testEval "(reverse (list 3 2 1))",              [1,2,3]
    testEval "(append (list 1) (list 2 3))",        [1,2,3]
    testEval "(append (list 1) (list 2) (list 3))", [1,2,3]

  suite "caar, etc", ->
    testEval "(cddr (list 1 2 3))", [3]
    testEval "(caddr (list 1 2 3))", 3
