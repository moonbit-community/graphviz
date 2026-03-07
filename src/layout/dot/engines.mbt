///|
/// Unranked engine public APIs: root-level error mapping plus layout-tree to
/// public-layout bridging for neato/noop entry paths.

///|
pub fn layout_neato(
  graph : @cgraph.Graph,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  @label_layout.reset_label_caches()
  let layout_tree =
    match @unranked_engine.prepare_neato_layout_tree(graph, scale, prune) {
      Ok(value) => value
      Err(message) => raise DotLayoutError::InvalidGraph(message~)
    }
  dot_layout_graph_from_layout_tree(layout_tree)
}

///|
pub fn layout_neato_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  @label_layout.reset_label_caches()
  let layout_tree =
    match @unranked_engine.prepare_noop_layout_tree(
      graph,
      no_op_level,
      scale,
      prune,
    ) {
      Ok(value) => value
      Err(message) => raise DotLayoutError::InvalidGraph(message~)
    }
  dot_layout_graph_from_layout_tree(layout_tree)
}

///|
pub fn layout_dot_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  layout_neato_noop(
    graph,
    no_op_level=no_op_level,
    scale=scale,
    prune=prune,
  )
}
