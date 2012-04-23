countTree = (tree) ->
  countc = (t,n,c) ->
    if t?
      countc(
        t.left
        n + 1
        (n) ->
          countc(
            t.right
            n
            c
          )
      )
    else
      c n
  ans = 0
  countc tree, 0, (n) -> ans = n

add_elem = (tree,value) ->
  if !tree?
    data: value
    left: null
    right: null
  else if value <= tree.data
    data: tree.data
    left: add_elem tree.left, value
    right: tree.right
  else
    data: tree.data
    left: tree.left
    right: add_elem tree.right, value

reduce = (f, init, lst) ->
  curr = init
  curr = f(curr, val) for val in lst
  curr

create_tree = (lst) ->
  reduce(
    (tree, elem) -> add_elem(tree, elem),
    null,
    lst
  )

console.log countTree null

console.log countTree create_tree ['b', 'a']
