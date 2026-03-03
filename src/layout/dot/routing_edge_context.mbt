///|
/// Graphviz parity: ordered-edge routing context captures pass-stable routing
/// inputs, including prepass-derived ordering/grouping state.
priv struct OrderedEdgeRoutingContext {
  base_cache : Map[Int, EdgeRouteBase]
  prepass : @routing.RoutePrepassState
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
  ranksep_pt : Double
  has_clusters : Bool
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  flat_label_edge_vnodes : Map[String, String]
  routing_context : RoutingContext
  enable_complex_tuning : Bool
  path_adjacency : @routesplines.PathAdjacency
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
  build_base_for_edge : (@cgraph.Edge) -> EdgeRouteBase
}

///|
/// Graphviz parity: ordered-edge routing mutates only shared pass-level maps
/// while iterating in Graphviz-compatible route order.
priv struct OrderedEdgeRoutingState {
  recovered_slack_keys : Map[String, Bool]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  edges_out_by_id : Map[Int, DotLayoutEdge]
}

///|
/// Graphviz parity: ordered-edge routing context construction keeps prepass
/// setup (sameport/base-cache/order/group/bounds) in one place before routing.
/// Do not change behavior without updating fixtures/tests.
fn build_ordered_edge_routing_context(
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
) -> OrderedEdgeRoutingContext {
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
      routing_context.path_order_index,
      positions,
      vnode_positions,
      sizes,
      vnode_info.vnode_sizes,
      x_groups,
    )
  let self_edge_groups = @routing.collect_self_edge_groups(edges)
  {
    base_cache,
    prepass,
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
    ranksep_pt,
    has_clusters,
    label_edge_counts,
    head_port_metrics,
    flat_label_edge_vnodes,
    routing_context,
    enable_complex_tuning,
    path_adjacency: routing_context.path_adjacency,
    self_edge_groups,
    build_base_for_edge,
  }
}
