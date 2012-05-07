env = {}
t = null
SU = ScheemUtils
{intern, unintern} = SU

renderProgram = (exprs, $target) ->
  for expr,i in exprs
    element = renderExpr expr
    element.data().exprNumber = i
    $target.append element

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
            if SU.isSpecialForm expr[0] then renderSpecialForm expr
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
  o = $('#output');

  e.hide();
  $().add(o).add(s).html('');

  if $.trim(src) == '' then return

  try
    p = SCHEEM.parse(src, 'program')
  catch ex
    e.text("Parse error: #{ex} at line #{ex.line}, column: #{ex.column}").show()
    return

  renderProgram p, s

  try
    res = evalScheemProgram(src, env)
  catch ex
    e.text("Runtime error: #{ex}").show()
    return

  o.append($("<span class='result'></span>").text(" => #{printScheem res.result}"))

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

$(".example").click ->
  clearTimeout t
  editor.setValue $(this).find('code').text()
  compileAndRun editor.getValue()
