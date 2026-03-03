///|
/// Graphviz parity: ordered-edge routing context captures one pass snapshot
/// so per-edge routing only mutates shared pass state.
priv struct OrderedEdgeRoutingContext {
  base_cache : Map[Int, EdgeRouteBase]
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  ranks : Map[String, Int]
  splines : SplinesMode
  sizes : Map[String, NodeSize]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  path_left_bound : Double
  path_right_bound : Double
  ranksep_pt : Double
  has_clusters : Bool
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  flat_label_edge_vnodes : Map[String, String]
  routing_context : RoutingContext
  enable_complex_tuning : Bool
  path_adjacency : @routesplines.PathAdjacency
  recover_edge_id_for_routing : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
  build_base_for_edge : (@cgraph.Edge) -> EdgeRouteBase
}

///|
/// Graphviz parity: ordered-edge routing mutates only these shared maps while
/// walking edges in graphviz-compatible order.
priv struct OrderedEdgeRoutingState {
  recovered_slack_keys : Map[String, Bool]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  edges_out_by_id : Map[Int, DotLayoutEdge]
}

///|
/// Graphviz parity: ordered edge routing loop preserves flat-adjacent,
/// self-edge, regular-edge branch order from dot.
/// Do not change behavior without updating fixtures/tests.
fn route_ordered_edge(
  edge : @cgraph.Edge,
  context : OrderedEdgeRoutingContext,
  state : OrderedEdgeRoutingState,
) -> Unit {
  let edge_id = edge.id()
  if state.edges_out_by_id.get(edge_id) is Some(_) {
    return ()
  }
  let base = match context.base_cache.get(edge_id) {
    Some(value) => value
    None => return ()
  }
  match context.flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        build_flat_adjacent_layout(
          base,
          bezier,
          context.ranks,
          context.rank_y,
          context.vnode_info,
          context.vnode_positions,
          context.nodesep_pt,
          context.has_clusters,
          context.flat_label_edge_vnodes,
        )
      state.edges_out_by_id[edge_id] = edge_layout
      return ()
    }
    None => ()
  }
  if maybe_build_self_edge_layout(
    edge,
    base,
    context.self_edge_groups,
    context.base_cache,
    context.build_base_for_edge,
    context.ranks,
    context.nodesep_pt,
    context.rank_y,
    context.vnode_info,
    context.vnode_positions,
    context.has_clusters,
    context.flat_label_edge_vnodes,
    state.self_edge_routes,
    state.edges_out_by_id,
  ) {
    return ()
  }
  let regular_layout = build_regular_spline_layout(
    edge,
    base,
    context.splines,
    context.ranks,
    context.sizes,
    context.positions,
    context.vnode_positions,
    context.vnode_info,
    context.rank_y,
    context.rank_ht1,
    context.rank_ht2,
    context.x_groups,
    context.nodesep_pt,
    context.path_left_bound,
    context.path_right_bound,
    context.ranksep_pt,
    context.label_edge_counts,
    context.head_port_metrics,
    context.routing_context,
    context.enable_complex_tuning,
    context.has_clusters,
    context.flat_label_edge_vnodes,
    context.path_adjacency,
    context.recover_edge_id_for_routing,
    state.recovered_slack_keys,
  )
  state.edges_out_by_id[edge_id] = regular_layout.edge_layout
  apply_regular_parallel_reuse_layouts(
    edge,
    regular_layout,
    context.regular_parallel_groups,
    context.base_cache,
    state.edges_out_by_id,
    context.ranks,
    context.rank_y,
    context.vnode_info,
    context.vnode_positions,
    context.nodesep_pt,
    context.has_clusters,
    context.flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: ordered-edge routing loop keeps mutable self-edge and
/// recover-slack state shared across edges in pass order.
/// Do not change behavior without updating fixtures/tests.
fn route_ordered_edges(
  ordered_edges : Array[@cgraph.Edge],
  context : OrderedEdgeRoutingContext,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let state : OrderedEdgeRoutingState = {
    recovered_slack_keys: Map::new(),
    self_edge_routes: Map::new(),
    edges_out_by_id,
  }
  for edge in ordered_edges {
    route_ordered_edge(
      edge,
      context,
      state,
    )
  }
}
