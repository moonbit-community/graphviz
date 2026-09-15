///|
test "single rank honors flat edge order independently of node declaration order" {
  for names in [["a", "b"], ["b", "a"]] {
    let graph = @cgraph.Graph::new(@cgraph.Directed)
    for name in names {
      let node = graph.node(name)
      node.set_attr("shape", "box")
      node.set_attr("label", "")
    }
    let same = graph.subgraph()
    same.set_attr("rank", "same")
    ignore(same.node("b"))
    ignore(same.node("a"))
    graph.edge(graph.node("b"), graph.node("a")).set_attr("dir", "back")
    let layout = layout_dot(graph)
    let a = layout.nodes.filter(node => node.node.name() == "a")[0]
    let b = layout.nodes.filter(node => node.node.name() == "b")[0]
    @test.assert_eq(b.pos.x < a.pos.x, true)
    @test.assert_eq(a.pos.y, b.pos.y)
  }
}

///|
test "zero weight flat edges do not impose an ordering constraint" {
  for weight in ["0", "0.4", "0.6"] {
    let graph = @cgraph.Graph::new(@cgraph.Directed)
    let a = graph.node("a")
    let b = graph.node("b")
    let same = graph.subgraph()
    same.set_attr("rank", "same")
    ignore(same.node("a"))
    ignore(same.node("b"))
    graph.edge(b, a).set_attr("weight", weight)
    let layout = layout_dot(graph)
    let a = layout.nodes.filter(node => node.node.name() == "a")[0]
    let b = layout.nodes.filter(node => node.node.name() == "b")[0]
    @test.assert_eq(a.pos.x < b.pos.x, true)
    @test.assert_eq(a.pos.y, b.pos.y)
  }
}

///|
test "nonconstraint flat edges still group connected nodes before rankdir flipping" {
  for rankdir in ["TB", "BT", "LR", "RL"] {
    let graph = @cgraph.Graph::new(@cgraph.Directed)
    graph.set_attr("rankdir", rankdir)
    for name in ["a", "b", "c"] {
      ignore(graph.node(name))
    }
    let same = graph.subgraph()
    same.set_attr("rank", "same")
    for name in ["a", "b", "c"] {
      ignore(same.node(name))
    }
    graph.edge(graph.node("c"), graph.node("a")).set_attr("constraint", "false")
    let nodes = layout_dot(graph).nodes
    let a = nodes.filter(node => node.node.name() == "a")[0]
    let b = nodes.filter(node => node.node.name() == "b")[0]
    let c = nodes.filter(node => node.node.name() == "c")[0]
    if rankdir == "TB" || rankdir == "BT" {
      @test.assert_eq(a.pos.x < c.pos.x && c.pos.x < b.pos.x, true)
    } else {
      @test.assert_eq(b.pos.y > a.pos.y && a.pos.y > c.pos.y, true)
    }
  }
}

///|
test "flat sibling order follows node ids rather than edge statement order" {
  for targets in [["a", "b"], ["b", "a"]] {
    let graph = @cgraph.Graph::new(@cgraph.Directed)
    for name in ["c", "b", "a"] {
      ignore(graph.node(name))
    }
    let same = graph.subgraph()
    same.set_attr("rank", "same")
    for name in ["a", "b", "c"] {
      ignore(same.node(name))
    }
    for target in targets {
      ignore(graph.edge(graph.node("c"), graph.node(target)))
    }
    let nodes = layout_dot(graph).nodes
    let a = nodes.filter(node => node.node.name() == "a")[0]
    let b = nodes.filter(node => node.node.name() == "b")[0]
    let c = nodes.filter(node => node.node.name() == "c")[0]
    @test.assert_eq(c.pos.x < a.pos.x && a.pos.x < b.pos.x, true)
  }
}
