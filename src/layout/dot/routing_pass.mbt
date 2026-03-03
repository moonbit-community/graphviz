///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  splines : SplinesMode,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> Array[DotLayoutEdge] {
  let path_adjacency = routing_context.path_adjacency
  let path_order_index = routing_context.path_order_index
  let self_edge_groups = @routing.collect_self_edge_groups(edges)
  let sameport_overrides = collect_sameport_overrides(
    edges,
    positions,
    sizes,
    record_orientation,
    layout_rankdir,
    ranksep_pt,
  )
  let build_base_for_edge =
    (edge : @cgraph.Edge) =>
      build_edge_route_base(
        graph.kind(),
        edge,
        ranks,
        sizes,
        positions,
        record_orientation,
        label_ports_map,
        label_ports_raw,
        routing_context,
        rankdir,
        layout_rankdir,
        enable_complex_tuning,
        vnode_info.edge_vnodes,
        sameport_overrides,
      )
  let base_cache =
    @routing.build_route_base_cache(
      edges,
      build_base_for_edge,
    )
  let prepass =
    @routing.build_route_prepass_state(
      edges,
      base_cache,
      splines == SplinesMode::Spline,
      ranks,
      routing_context.order_index,
      path_order_index,
      positions,
      vnode_positions,
      sizes,
      vnode_info.vnode_sizes,
      x_groups,
    )
  let flat_adjacent_simple_beziers = prepass.flat_adjacent_simple_beziers
  let path_left_bound = prepass.path_left_bound
  let path_right_bound = prepass.path_right_bound
  let ordered_edges = prepass.ordered_edges
  let recover_edge_id_for_routing = prepass.recover_edge_id_for_routing
  let regular_parallel_groups = prepass.regular_parallel_groups
  let ordered_edge_routing_context : OrderedEdgeRoutingContext = {
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
    regular_parallel_groups,
    self_edge_groups,
    build_base_for_edge,
  }
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  route_ordered_edges(
    ordered_edges,
    ordered_edge_routing_context,
    edges_out_by_id,
  )
  finalize_routed_edges(edges, ranks, edges_out_by_id)
}
