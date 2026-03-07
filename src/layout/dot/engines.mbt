///|
/// Unranked engine entry paths: public noop/neato APIs plus root-owned
/// error mapping and unranked-engine orchestration.

///|
fn neato_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => @numeric.parse_double_or(value, @input_stage.DEFAULT_NODESEP_IN)
    None => @input_stage.DEFAULT_NODESEP_IN
  }
  nodesep_in * 72.0
}

///|
fn validate_neato_edge_lengths(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for edge in graph.edges() {
    match edge.get_attr("len") {
      Some(value) =>
        if @numeric.parse_first_double(value, 0.0) < 0.0 {
          raise DotLayoutError::InvalidGraph(
            message="edge \{edge.tail().name()} -> \{edge.head().name()} has negative len: \{value}",
          )
        }
      None => ()
    }
  }
}

///|
pub fn layout_neato(
  graph : @cgraph.Graph,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  let active_graph = @unranked_engine.active_graph_for_prune(graph, prune)
  match @input_stage.validate_layout_graph(active_graph) {
    Ok(_) => ()
    Err(message) => raise DotLayoutError::InvalidGraph(message~)
  }
  @label_layout.reset_label_caches()
  validate_neato_edge_lengths(active_graph)
  dot_layout_graph_from_layout_tree(
    @unranked_engine.build_neato_layout_tree(
      active_graph,
      scale,
      neato_nodesep_pt(active_graph),
    ),
  )
}

///|
pub fn layout_neato_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  let active_graph = @unranked_engine.active_graph_for_prune(graph, prune)
  @label_layout.reset_label_caches()
  let layout_tree =
    match @unranked_engine.build_noop_layout_tree(active_graph, no_op_level, scale) {
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
