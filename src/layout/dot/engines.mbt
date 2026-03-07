///|
/// Unranked engine entry paths: public noop/neato APIs plus root-owned input
/// parsing and validation.

type EngineNodeProjectionWithSizes = @unranked_engine.EngineNodeProjectionWithSizes

///|
fn collect_noop_nodes_with_sizes(
  graph : @cgraph.Graph,
  scale_factor : Double,
  record_orientation : RecordOrientation,
) -> EngineNodeProjectionWithSizes raise DotLayoutError {
  let nodes = graph.nodes()
  let positions : Map[String, @geom.Point] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let pos = parse_required_noop_node_pos(node, scale_factor)
    positions[node.name()] = pos
    sizes[node.name()] = @node_geometry.node_size(node, record_orientation)
  }
  let nodes_out =
    @unranked_engine.build_projected_nodes_from_positions(
      nodes,
      positions,
      node =>
        @unranked_engine.node_size_with_fallback(sizes, node, record_orientation),
    )
  {
    projection: { positions, nodes_out },
    sizes,
  }
}

///|
fn neato_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => @dot_shared.parse_double_or(value, default_nodesep_in())
    None => default_nodesep_in()
  }
  nodesep_in * 72.0
}

///|
fn validate_neato_edge_lengths(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for edge in graph.edges() {
    match edge.get_attr("len") {
      Some(value) =>
        validate_nonnegative_attr(
          "edge \{edge.tail().name()} -> \{edge.head().name()}",
          "len",
          value,
          @dot_shared.parse_first_double(value, 0.0),
        )
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
  validate_layout_graph(active_graph)
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
fn parse_required_noop_node_pos(
  node : @cgraph.Node,
  scale_factor : Double,
) -> @geom.Point raise DotLayoutError {
  let pos_value = match node.get_attr("pos") {
    Some(value) => value
    None =>
      raise DotLayoutError::InvalidGraph(
        message="neato -n requires pos for node \{node.name()}",
      )
  }
  let parsed = match @unranked_engine.parse_point_attr(pos_value) {
    Some(value) => value
    None =>
      raise DotLayoutError::InvalidGraph(
        message="invalid pos for node \{node.name()}",
      )
  }
  @unranked_engine.scale_point(parsed, scale_factor)
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
  let geometry = @unranked_engine.build_engine_geometry_context(active_graph, scale)
  let node_data =
    collect_noop_nodes_with_sizes(
      active_graph,
      geometry.scale_factor,
      geometry.record_orientation,
    )
  let use_edge_pos = no_op_level > 1
  let node_size_for = (node : @cgraph.Node) =>
    @unranked_engine.node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  let edges_out =
    @unranked_engine.build_edges_from_positions(
      active_graph,
      node_data.projection.positions,
      node_size_for,
      (edge, tail_pos, head_pos, tail_size, head_size) =>
        @unranked_engine.noop_edge_splines(
          edge,
          use_edge_pos,
          geometry.scale_factor,
          tail_pos,
          head_pos,
          tail_size,
          head_size,
        ),
    )
  dot_layout_graph_from_layout_tree(
    @unranked_engine.finalize_unranked_layout_tree(
      active_graph,
      geometry.rankdir,
      node_data.projection.nodes_out,
      edges_out,
    ),
  )
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
