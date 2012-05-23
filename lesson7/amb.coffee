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

_.trampoline = trampoline = (thk) ->
  while typeof thk == 'object' and thk.tag?
    switch thk.tag
      when 'value' then return thk.val
      when 'thunk'
        thk = thk.func((thk.args ? [])...)
  return thk

_.ambeval = ambeval = (func, onFailure) ->
  makeAmb = (failCont) ->
    fail = thunk failCont, []
    amb = (lst, cont) ->
      if !lst? || lst.length == 0
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
  trampoline(
    thunk(
      func
      [ onFailure ? makeAmb -> throw new Error "Ran out of fail continuations" ]
    )
  )


ambeval (amb) ->
  amb [1..5], (a, amb) ->
    amb [a+1..5], (b, amb) ->
      amb [b+1..5], (h, amb) ->
        return amb() unless (a*a + b*b) == h*h
        console.log "#{a}^2 + #{b}^2 = #{h}^2"

ambeval (amb) ->
  slots = [1,2,3,4,5]
  except = (val, lst) ->
    (i for i in lst when i != val)
  amb slots, (baker, amb) ->
    cslots = except baker, slots
    amb cslots, (cooper, amb) ->
      fslots = except cooper, cslots
      amb fslots, (fletcher, amb) ->
        mslots = except fletcher, fslots
        amb mslots, (miller, amb) ->
          sslots = except miller, mslots
          amb sslots, (smith, amb) ->
#            return amb() unless (baker != cooper != fletcher != miller != smith)
            return amb() unless baker != 5
            return amb() unless cooper != 1
            return amb() unless  1!= fletcher != 5
            return amb() unless miller > cooper
            return amb() unless 1 != Math.abs(smith - fletcher)
            return amb() unless 1 != Math.abs(fletcher - cooper)
            console.log(
              baker: baker
              cooper: cooper
              fletcher: fletcher
              miller: miller
              smith: smith
            )
