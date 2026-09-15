///|
test "DOT weights use integer prefixes and clamp negative values" {
  let weight = (value : String) => {
    let graph = @cgraph.Graph::new(@cgraph.Directed)
    let edge = graph.edge(graph.node("a"), graph.node("b"))
    edge.set_attr("weight", value)
    edge_weight(edge)
  }
  for text in ["0.6", "0.4", "0tail", "-1", "-999999999999999999999"] {
    @test.assert_eq(weight(text), weight("0"))
  }
  for text in ["2.9", "2e3", "  +2suffix"] {
    @test.assert_eq(weight(text), weight("2"))
  }
  for text in ["", "garbage", "+", "-", "999999999999999999999"] {
    @test.assert_eq(weight(text), weight("1"))
  }
}
