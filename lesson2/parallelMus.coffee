max = (a,b) -> Math.max(a,b)
map = (xs, f) -> f x for x in xs

endTime = (time, expr) ->
    switch expr.tag
        when 'note' then time + expr.dur
        when 'rest' then time + expr.duration
        when 'par'
            max(
                endTime time, expr.left
                endTime time, expr.right
            )
        when 'seq'
            endTime(
                endTime time, expr.left
                expr.right
            )

convertPitch = (note) ->
  [letter, octave] = note.split ''
  letterPitch = 'c d ef g a b'.indexOf(letter.toLowerCase())
  12 + 12 * parseInt(octave, 10) + letterPitch

compile = (musexpr) ->
    notes = []
    comp = (expr, time) ->
        switch expr.tag
            when 'note'
                notes.push
                    tag: expr.tag
                    dur: expr.dur
                    pitch: convertPitch expr.pitch
                    start: time
            when 'par'
                comp expr.left, time
                comp expr.right, time
            when 'seq'
                comp expr.left, time
                comp expr.right, endTime(time, expr.left)
    comp musexpr, 0
    return notes

note = (p, d) ->
  tag: 'note',
  pitch: p
  dur: d

rest = (dur) ->
  tag: 'rest'
  duration: dur

melody_mus =
  tag: 'seq'
  left:
    tag: 'seq'
#    left: note 'a4', 250
    left: rest 100
    right: note 'b4', 250
  right:
    tag: 'seq'
    left: note 'c4', 250
    right: note 'd4', 250



console.log melody_mus
console.log compile melody_mus
