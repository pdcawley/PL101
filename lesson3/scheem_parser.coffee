PEG = require "pegjs"
assert = require "assert"
fs = require "fs"

fs.readFile 'scheem.peg', 'ascii', (err, data) ->
  parser = PEG.buildParser(data, {trackLineAndColumn: true})
  parse = parser.parse

  assertParses = (input, expected) ->
    assert.deepEqual parse(input), expected

  assertBadParse = (input) ->
    assert.throws () -> parse(input)

  assertParses ";; foo\n(atom)    ", ["atom"]
  assertParses "atom", "atom"
  assertParses "atom\n;; foo\n", "atom"
  assertParses "'(a  (b  c  ) )", ["quote", ["a", ["b", "c"]]]
  assertParses "(if #t 1 0)", ["if", "#t", 1, 0]

  assertBadParse """
    (a (b ;; t <- I think this should work
        c))
  """, ["a", ["b", "c"]]
  assertBadParse "(define (fact n) (if (= n 0) 1 (* n (fact (- n 1))))) (fact 10)"
