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
