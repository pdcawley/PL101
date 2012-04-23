(function() {
  var add_elem, countTree, create_tree, reduce;

  countTree = function(tree) {
    var ans, countc;
    countc = function(t, n, c) {
      if (t != null) {
        return countc(t.left, n + 1, function(n) {
          return countc(t.right, n, c);
        });
      } else {
        return c(n);
      }
    };
    ans = 0;
    return countc(tree, 0, function(n) {
      return ans = n;
    });
  };

  add_elem = function(tree, value) {
    if (!(tree != null)) {
      return {
        data: value,
        left: null,
        right: null
      };
    } else if (value <= tree.data) {
      return {
        data: tree.data,
        left: add_elem(tree.left, value),
        right: tree.right
      };
    } else {
      return {
        data: tree.data,
        left: tree.left,
        right: add_elem(tree.right, value)
      };
    }
  };

  reduce = function(f, init, lst) {
    var curr, val, _i, _len;
    curr = init;
    for (_i = 0, _len = lst.length; _i < _len; _i++) {
      val = lst[_i];
      curr = f(curr, val);
    }
    return curr;
  };

  create_tree = function(lst) {
    return reduce(function(tree, elem) {
      return add_elem(tree, elem);
    }, null, lst);
  };

  console.log(countTree(null));

  console.log(countTree(create_tree(['b', 'a'])));

}).call(this);
