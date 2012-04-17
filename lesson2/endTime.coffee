endTime = (time, expr) ->
  switch expr.tag
    when 'note' then time + expr.dur
    when 'seq'
      endTime(
        endTime(time,  expr.left)
        expr.right
      )

notes = (expr, array) ->
    array ?= []
    switch expr.tag
        when 'note' then array + [expr]
        when 'seq'
            notes(
                expr.right
                notes(expr.left, array)
            )

eachNote = (expr, f) ->
    switch expr.tag
        when 'note' then f expr
        when 'seq'
            eachNote expr.left, f
            eachNote expr.right, f

notes = (expr) ->
    result = []
    eachNote expr, (note) -> result.push note
    result

endTime = (time, expr) ->
    eachNote expr, (n) -> time += n.dur
    return time

compile = (musexpr) ->
    notesexpr = []
    startTime = 0
    eachNote musexpr, (note) ->
        notesexpr.push
            tag: note.tag
            dur: note.dur
            pitch: note.pitch
            start: startTime
        startTime += note.dur
    return notesexpr

compose = (f, g) ->
    (args...) -> f g args...

playMus = compose playNote compile
