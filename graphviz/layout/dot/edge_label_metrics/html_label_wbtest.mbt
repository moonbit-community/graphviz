///|
test "HTML edge labels measure tables instead of source markup" {
  let graph = @dot_parser.parse_dot(
    "digraph { a -> b [label=<<TABLE><TR><TD BGCOLOR=\"red\" WIDTH=\"10\"> </TD><TD>Edge labels<BR/>also</TD><TD BGCOLOR=\"blue\" WIDTH=\"10\"> </TD></TR></TABLE>>]; }",
  )
  guard edge_mid_label_metrics(graph.edges()[0]) is Some(metrics) else {
    fail("expected label metrics")
  }
  @test.assert_eq(metrics.width, 99.0)
  @test.assert_eq(metrics.height, 45.0)
}
