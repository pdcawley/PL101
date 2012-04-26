PEG = require "pegjs"
fs = require "fs"

MUS = { bpm: 120 }

MUS.note = note = (p, d) ->
  tag: 'note',
  pitch: p
  dur: d

MUS.rest = rest = (dur) ->
  tag: 'rest'
  duration: dur

MUS.rep = rep = (count, expr) ->
  ret =
    tag: 'repeat'
    section: expr
    'count': count
  ret

MUS.seq = seq = (lst) ->
  [expr, exprs...] = lst
  switch exprs.length
    when 0 then expr
    else
      tag: 'seq'
      left: expr
      right: seq exprs

MUS.par = par = (lst) ->
  [expr, exprs...] = lst
  switch exprs.length
    when 0 then expr
    else
      tag: 'par',
      left: expr
      right: par exprs

MUS.swung_pair = swung_pair = (n, p) ->
  total = n.dur * 2;
  firstDur = 3 * n.dur / 2
  seq(note(n.pitch, firstDur), note(p, total - firstDur))

MUS.triplet = triplet = (events, duration) ->
  total = duration * 2
  eventLen = duration / 3

  event.dur = eventLen for event in events
  events[1].dur = total - 2 * eventLen
  seq events...


MUS.beatLen = beatLen = () ->
  60000 / this.bpm

MUS.withParser = withParser = (f) ->
  fs.readFile 'mymus.peg', 'ascii', (err, data) ->
    f(PEG.buildParser(data, {trackLineAndColumn: true}))

if module? then module.exports = MUS
