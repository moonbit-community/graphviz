///|
/// Unranked engine entry paths: root-only final layout assembly plus public
/// noop/neato API boundaries.

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
/// Graphviz parity: noop/neato output assembly mirrors dot postprocess shape:
/// cluster subgraph recursion + bbox expansion + root label placement.
fn finalize_unranked_layout_graph(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> DotLayoutGraph {
  let base_bbox = @bbox.compute_bbox(nodes_out, edges_out)
  let empty_cluster_ln_x : Map[String, Double] = Map::new()
  let empty_cluster_rn_x : Map[String, Double] = Map::new()
  let empty_cluster_bbox_heights : Map[String, ClusterBboxHeightPair] = Map::new()
  let empty_ranks : Map[String, Int] = Map::new()
  let empty_rank_y : Map[Int, Double] = Map::new()
  let empty_rank_ht1 : Map[Int, Double] = Map::new()
  let empty_rank_ht2 : Map[Int, Double] = Map::new()
  let subgraph_trees =
    @clustering.layout_subgraphs(
      {
        graph,
        nodes_out,
        edges_out,
        cluster_ln_x: empty_cluster_ln_x,
        cluster_rn_x: empty_cluster_rn_x,
        cluster_bbox_heights: empty_cluster_bbox_heights,
        rankdir,
        ranks: empty_ranks,
        rank_y: empty_rank_y,
        rank_ht1: empty_rank_ht1,
        rank_ht2: empty_rank_ht2,
      },
    )
  let mut final_bbox = if subgraph_trees.length() > 0 {
    @clustering.expand_bbox_with_subgraphs(base_bbox, subgraph_trees)
  } else {
    base_bbox
  }
  let subgraphs = dot_layout_graphs_from_layout_trees(subgraph_trees)
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match @label_metrics.graph_label_metrics(graph) {
      Some(metrics) => {
        let loc = @dot_shared.graph_label_loc(graph)
        let just = @dot_shared.graph_label_just(graph)
        final_bbox =
          @dot_shared.expand_bbox_for_label(
            final_bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
          )
        label_pos = Some(
          @dot_shared.graph_label_pos(
            final_bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
            just,
          ),
        )
      }
      None => ()
    }
  }
  {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: nodes_out,
    edges: edges_out,
    subgraphs,
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
  let geometry = @unranked_engine.build_engine_geometry_context(active_graph, scale)
  let nodes = active_graph.nodes()
  let node_count = nodes.length()
  let sizing = @unranked_engine.build_neato_node_sizing(nodes, geometry.record_orientation)
  let nodesep_pt = neato_nodesep_pt(active_graph)
  let base_spacing = sizing.max_half * 2.0 + nodesep_pt
  let spacing = if base_spacing <= 1.0 { 1.0 } else { base_spacing }
  let node_state = @unranked_engine.build_neato_initial_node_state(nodes, spacing)
  let positions = node_state.positions
  let pinned = node_state.pinned
  let edges = @unranked_engine.build_neato_edges(
    active_graph,
    sizing.indices,
    sizing.radii,
    nodesep_pt,
  )
  if node_count > 1 {
    @unranked_engine.relax_positions(
      positions,
      pinned,
      sizing.radii,
      edges,
      spacing,
      nodesep_pt,
      100,
    )
  }
  let node_data =
    @unranked_engine.project_scaled_nodes_with_sizes(
      nodes,
      positions,
      geometry.scale_factor,
      sizing.sizes,
      geometry.record_orientation,
    )
  let node_size_for = (node : @cgraph.Node) =>
    @unranked_engine.node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  let edges_out =
    @unranked_engine.build_edges_from_positions(
      active_graph,
      node_data.projection.positions,
      node_size_for,
      @unranked_engine.straight_line_edge_splines,
    )
  finalize_unranked_layout_graph(
    active_graph,
    geometry.rankdir,
    node_data.projection.nodes_out,
    edges_out,
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
  finalize_unranked_layout_graph(
    active_graph,
    geometry.rankdir,
    node_data.projection.nodes_out,
    edges_out,
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
