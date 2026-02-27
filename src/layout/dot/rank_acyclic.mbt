///|
/// Rank domain: acyclic edge-direction preprocessing helpers.

///|
fn acyclic_edge_directions(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (Array[String], Array[String], Array[Bool]) {
  @rank_assignment.acyclic_edge_directions(
    graph,
    nodes,
    edges,
    edge_is_constraint,
    build_graphviz_nlist_order_from_edges,
  )
}

///|
fn acyclic_edge_directions_with_order(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (
  Array[String],
  Array[String],
  Array[Bool],
  Array[Array[Int]],
  Array[Array[Int]],
) {
  @rank_assignment.acyclic_edge_directions_with_order(
    graph,
    nodes,
    edges,
    edge_is_constraint,
    build_graphviz_nlist_order_from_edges,
  )
}

///|
fn acyclic_edge_directions_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_is_active : Array[Bool],
) -> (Array[String], Array[String], Array[Bool]) {
  @rank_assignment.acyclic_edge_directions_for_names(
    node_names,
    edge_tail,
    edge_head,
    edge_is_active,
  )
}
