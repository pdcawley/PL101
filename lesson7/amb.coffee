if module?
  _ = module.exports
else
  _ = window

_.thunk = thunk = (f, lst) ->
  tag: "thunk"
  func: f
  args: lst

_.thunkValue = thunkValue = (val) ->
  tag: "value"
  val: val

_.trampoline = (thk) ->
  while typeof thk == 'object' and thk.tag?
    switch thk.tag
      when 'value' then return thk.val
      when 'thunk'
        thk = thk.func((thk.args ? [])...)
  return thk

_.ambeval = (func, onFailure) ->
  makeAmb = (failCont) ->
    fail = thunk failCont, []
    amb = (lst, cont) ->
      switch typeof lst
        when 'object'
          if lst.length is 0
            return fail
          else
            [choice, choices...] = lst
            return thunk(
              cont
              [
                choice
                makeAmb -> amb choices, cont
              ]
            )
        else
          if ! lst
            return fail
          else
            return thunk cont, [lst, amb]

  trampoline(
    thunk(
      func
      [ onFailure ? makeAmb -> throw new Error "Ran out of fail continuations" ]
    )
  )


ambeval (amb, fail) ->
  amb [1..5], (a, amb) ->
    amb [a+1..5], (b, amb) ->
      amb [b+1..5], (h, amb) ->
        amb(
          ((a*a + b*b) == h*h)
          -> console.log "#{a}^2 + #{b}^2 = #{h}^2"
        )
