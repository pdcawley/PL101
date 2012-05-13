env = {}
t = null
SU = ScheemUtils
{intern, unintern} = SU

renderProgram = (exprs, $target) ->
  for expr,i in exprs
    element = renderExpr expr
    element.data().exprNumber = i
    $target.append element.wrap('<p class="top-level"></p>').parent()

renderExpr = (expr) ->
  switch typeof expr
    when 'undefined' then throw new Error "Undefined is not allowed!"
    when 'number'
      $("<span class='scheem-number'>").text(expr)
    when 'boolean'
      $("<span class='scheem-boolean'>").text( #
        if expr then '#t' else '#f'
      )
    when 'string'
      $("<span class='scheem-string'>\"#{expr}\"</span>")
    else
      if SU.isSymbol expr
        symbol = unintern expr
        $("<span class='scheem-symbol'>")
          .text(symbol).data('name', symbol)
      else
        switch expr.constructor.name
          when 'Array'
            if expr.length == 0
              $("<span class='scheem-quoted-expr'>" +
                "<span class='scheem-quote'>'</span>" +
                "<span class='scheem-lparen'>(</span>" +
                "<span class='scheem-rparen'>)</span></span>")
            else if SU.isSpecialForm expr[0] then renderSpecialForm expr
            else renderApplication expr
          when Function
            name = expr.value ? expr.key
            el = $("<span class='scheem-proc'>").text(
              if name? then "\#procedure:#{name}"
              else '#procedure'
            )
            if name then el.data('name', name)
            return el

renderSpecialForm = (expr) ->
  [specialForm, exprs...] = expr
  switch unintern specialForm
    when 'quote'
      el = $("<span class='scheem-quoted-expr'>" +
             "<span class='scheem-quote'>'</span></span>")
      el.append renderExpr exprs[0]
    else
      renderInExprList (el) ->
        el.append $("<span class='scheem-special-form'>").text(unintern specialForm)
        renderArgL exprs, el

renderApplication = (expr) ->
  [func, args...] = expr
  renderInExprList (el) ->
    funcEl =
      if SU.isSymbol func
        $("<span class='scheem-funcname'>")
          .text(unintern func).data('name', unintern func)
      else
        renderExpr func
    el.append funcEl
    renderArgL args, el

renderArgL = (args, target) ->
  for arg in args
    target.append '&ensp;'
    target.append renderExpr arg
  return target

renderInExprList = (f) ->
  el = $("<span class='scheem-expr'>")
  el.append $('<span class="scheem-lparen">(</span>')
  f el
  el.append $('<span class="scheem-lparen">)</span>')


compileAndRun = (src) ->
  e = $('#error')
  s = $('#preview')
  o = $('#output')
  t = $('#trace')
  r = $('#results')


  r.removeClass("alert-success alert-error")
  e.empty()

  if $.trim(src) == '' then return

  try
    p = SCHEEM.parse(src, 'program')
    r.addClass('alert-success').removeClass('alert-error')
  catch ex
    e.text("Parse error: #{ex} at line #{ex.line}, column: #{ex.column}").show()
    r.addClass('alert-error').removeClass('alert-success')
    return

  $().add(t).add(o).add(s).empty();
  renderProgram p, s

  try
    res = evalScheemProgram(src, env)
    r.addClass('alert-success').removeClass('alert-error')
  catch ex
    e.text("Runtime error: #{ex}").show()
    r.addClass('alert-error').removeClass('alert-success')
    return

  o.append($("<span class='result'></span>").text(" => #{printScheem res.result}"))

loadSource = (src) ->
  try
    env = evalScheemProgram(src, env).env
  catch ex
    console.log "Failed to load #{src} into the editor", ex


SU.defaultTracer =
  (->
    lastSym = null
    lastVal = null
    (exp, val) ->
      if SU.isSymbol(exp)
        if unintern(exp) == lastSym and val == lastVal
          return
        else
          lastSym = unintern exp
          lastVal = val

      line = $("<p><span class='trace-exp'></span> => <span class='trace-res'></span></p>")
      line.find('.trace-exp').text(printScheem exp)
      line.find('.trace-res').text(printScheem val)
      $('#trace').append(line)
  )()

editor = CodeMirror.fromTextArea(
  document.getElementById('editor')
  tabSize: 2
  indentWithTabs: false
  autoClearEmptyLines: true
  matchBrackets: true
  lineNumbers: true
  lineWrapping: true
  onChange: (e) ->
    clearTimeout t
    t = setTimeout(
      -> compileAndRun e.getValue()
      500
    )
)

compileAndRun editor.getValue()

addToEditor = (code) ->
  editor.setValue code.trim() + "\n"
  editor.focus()
  for i in [0 .. editor.lineCount() - 1]
    editor.indentLine i
  editor.setCursor(
    editor.lineCount() - 1
    0
  )


$(".example").click ->
  clearTimeout t
  editor.setValue $(this).find('code').text()
  compileAndRun editor.getValue()

$("#examples section header h1")
  .append( '<button class="show-hide">Show</button>' )
  .append( '<button class="insert-ex">Insert</button>' )
  .append( '<button class="load-ex">Load</button>' )
  .find('button').button()

$("#examples").on(
  'click'
  'header button.show-hide'
  (event) ->
    $(this).parents('header').next().toggle('blind')
    event.preventDefault()
    event.stopPropagation()
)
.on(
  'click'
  'button.insert-ex'
  (event) ->
    addToEditor($(this).parents('header').next().text())
    event.preventDefault()
    event.stopPropagation()
)
.on(
  'click'
  'button.load-ex'
  (e) ->
    loadSource($(this).parents('header').next().text())
    compileAndRun editor.getValue()
    event.stopPropagation()
)
