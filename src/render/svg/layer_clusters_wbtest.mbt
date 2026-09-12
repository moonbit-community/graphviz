///|
test "SVG cluster layer membership follows explicit selection before members" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_a")
  let node = cluster.node("a")
  node.set_attr("layer", "second")
  let selection = SvgLayerSelection::new("first:second", ":", ",")
  assert_false(selection.cluster_visible(1, cluster))
  assert_true(selection.cluster_visible(2, cluster))
  cluster.set_attr("layer", "first")
  assert_true(selection.cluster_visible(1, cluster))
  assert_false(selection.cluster_visible(2, cluster))
}
