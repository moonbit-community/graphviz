///|
fn new_test_graph(
  names : Array[String],
) -> (@cgraph.Graph, Map[String, @cgraph.Node]) {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node_map : Map[String, @cgraph.Node] = Map::new()
  for name in names {
    node_map[name] = graph.node(name)
  }
  (graph, node_map)
}

///|
fn sample_node_size(
  width_pt : Double,
  height_pt : Double,
) -> @node_primitives.NodeSize {
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}
