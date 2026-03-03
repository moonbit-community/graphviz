///|
/// Graphviz parity: ordered edge routing loop preserves flat-adjacent,
/// self-edge, regular-edge branch order from dot.
/// Do not change behavior without updating fixtures/tests.
fn route_ordered_edge(
  edge : @cgraph.Edge,
  base_cache : Map[Int, EdgeRouteBase],
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]],
  ranks : Map[String, Int],
  splines : SplinesMode,
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_for_routing : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]],
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  build_base_for_edge : (@cgraph.Edge) -> EdgeRouteBase,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let edge_id = edge.id()
  if edges_out_by_id.get(edge_id) is Some(_) {
    return ()
  }
  let base = match base_cache.get(edge_id) {
    Some(value) => value
    None => return ()
  }
  match flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        build_flat_adjacent_layout(
          base,
          bezier,
          ranks,
          rank_y,
          vnode_info,
          vnode_positions,
          nodesep_pt,
          has_clusters,
          flat_label_edge_vnodes,
        )
      edges_out_by_id[edge_id] = edge_layout
      return ()
    }
    None => ()
  }
  if maybe_build_self_edge_layout(
    edge,
    base,
    self_edge_groups,
    base_cache,
    build_base_for_edge,
    ranks,
    nodesep_pt,
    rank_y,
    vnode_info,
    vnode_positions,
    has_clusters,
    flat_label_edge_vnodes,
    self_edge_routes,
    edges_out_by_id,
  ) {
    return ()
  }
  let regular_layout = build_regular_spline_layout(
    edge,
    base,
    splines,
    ranks,
    sizes,
    positions,
    vnode_positions,
    vnode_info,
    rank_y,
    rank_ht1,
    rank_ht2,
    x_groups,
    nodesep_pt,
    path_left_bound,
    path_right_bound,
    ranksep_pt,
    label_edge_counts,
    head_port_metrics,
    routing_context,
    enable_complex_tuning,
    has_clusters,
    flat_label_edge_vnodes,
    path_adjacency,
    recover_edge_id_for_routing,
    recovered_slack_keys,
  )
  edges_out_by_id[edge_id] = regular_layout.edge_layout
  apply_regular_parallel_reuse_layouts(
    edge,
    regular_layout,
    regular_parallel_groups,
    base_cache,
    edges_out_by_id,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: ordered-edge routing loop keeps mutable self-edge and
/// recover-slack state shared across edges in pass order.
/// Do not change behavior without updating fixtures/tests.
fn route_ordered_edges(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]],
  ranks : Map[String, Int],
  splines : SplinesMode,
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_for_routing : Map[String, Int],
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]],
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  build_base_for_edge : (@cgraph.Edge) -> EdgeRouteBase,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let self_edge_routes : Map[Int, SelfEdgeRoute] = Map::new()
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  for edge in ordered_edges {
    route_ordered_edge(
      edge,
      base_cache,
      flat_adjacent_simple_beziers,
      ranks,
      splines,
      sizes,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      has_clusters,
      label_edge_counts,
      head_port_metrics,
      flat_label_edge_vnodes,
      routing_context,
      enable_complex_tuning,
      path_adjacency,
      recover_edge_id_for_routing,
      recovered_slack_keys,
      regular_parallel_groups,
      self_edge_groups,
      self_edge_routes,
      build_base_for_edge,
      edges_out_by_id,
    )
  }
}
