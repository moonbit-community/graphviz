///|
/// Graphviz parity: edge routing pass input bundles orchestration-time payload
/// so callsites preserve field mapping without long positional argument lists.
priv struct EdgeRoutingPassInput {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  sizes : Map[String, NodeSize]
  record_orientation : RecordOrientation
  rankdir : RankDir
  layout_rankdir : RankDir
  splines : SplinesMode
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : @routing.EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  ranksep_pt : Double
  has_clusters : Bool
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  label_edge_counts : Map[String, Int]
  head_port_metrics : @routing.HeadPortMetrics
  flat_label_edge_vnodes : Map[String, String]
  routing_context : @routing.RoutingContext
  enable_complex_tuning : Bool
}

///|
fn self_edge_label_height_pt_for_routes(
  edge : @cgraph.Edge,
  rankdir : RankDir,
) -> Double {
  match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.width
      } else {
        metrics.height
      }
    None => 0.0
  }
}

///|
fn build_edge_layout_for_input(
  base : @routing.EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : @routing.EdgeSplineResult,
  input : EdgeRoutingPassInput,
) -> DotLayoutEdge {
  @routing.build_edge_layout(
    base,
    spline,
    spline_result,
    {
      ranks: input.ranks,
      rank_y: input.rank_y,
      vnode_info: input.vnode_info,
      vnode_positions: input.vnode_positions,
      has_clusters: input.has_clusters,
      nodesep_pt: input.nodesep_pt,
      flat_label_edge_vnodes: input.flat_label_edge_vnodes,
    },
    (edge, ranks, mid_label_width_pt) =>
      match edge_label_rank_info(edge, ranks) {
        Some(info) =>
          if mid_label_width_pt > 0.0 {
            Some((info.label_rank, info.span))
          } else {
            None
          }
        None => None
      },
    edge_label_rank_y,
    (edge, label_rank, vnode_info, vnode_positions) =>
      edge_label_rank_x(
        edge,
        label_rank,
        vnode_info.vnode_ranks,
        vnode_info.edge_vnodes,
        vnode_positions,
      ),
    edge_label_pos_from_vnode,
    flat_edge_label_pos_simple,
    edge_label_pos,
    edge_port_label_pos,
  )
}

///|
fn spline_mode_for_regular_pass(splines : SplinesMode) -> Int {
  match splines {
    SplinesMode::None | SplinesMode::Polyline => 0
    SplinesMode::Ortho => 1
    _ => 2
  }
}

///|
fn build_route_base_cache(
  input : EdgeRoutingPassInput,
  sameport_overrides : SameportOverrides,
) -> Map[Int, @routing.EdgeRouteBase] {
  let base_cache : Map[Int, @routing.EdgeRouteBase] = Map::new()
  for edge in input.edges {
    let edge_id = edge.id()
    if base_cache.get(edge_id) is None {
      base_cache[edge_id] =
        build_edge_route_base(
          input.graph.kind(),
          edge,
          input.ranks,
          input.sizes,
          input.positions,
          input.record_orientation,
          input.label_ports_map,
          input.label_ports_raw,
          input.routing_context,
          input.rankdir,
          input.layout_rankdir,
          input.enable_complex_tuning,
          input.vnode_info.edge_vnodes,
          sameport_overrides,
        )
    }
  }
  base_cache
}

///|
fn build_route_edges_input(
  input : EdgeRoutingPassInput,
  base_cache : Map[Int, @routing.EdgeRouteBase],
) -> @routing.RouteEdgesInput {
  {
    edges: input.edges,
    ranks: input.ranks,
    sizes: input.sizes,
    positions: input.positions,
    vnode_positions: input.vnode_positions,
    vnode_info: input.vnode_info,
    rank_y: input.rank_y,
    rank_ht1: input.rank_ht1,
    rank_ht2: input.rank_ht2,
    x_groups: input.x_groups,
    nodesep_pt: input.nodesep_pt,
    ranksep_pt: input.ranksep_pt,
    label_edge_counts: input.label_edge_counts,
    head_port_metrics: input.head_port_metrics,
    flat_label_edge_vnodes: input.flat_label_edge_vnodes,
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
    use_spline_prepass: input.splines == SplinesMode::Spline,
    spline_mode: spline_mode_for_regular_pass(input.splines),
    base_cache,
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  input : EdgeRoutingPassInput,
) -> Array[DotLayoutEdge] {
  let sameport_overrides = collect_sameport_overrides(
    input.edges,
    input.positions,
    input.sizes,
    input.record_orientation,
    input.layout_rankdir,
    input.ranksep_pt,
  )
  let base_cache =
    build_route_base_cache(
      input,
      sameport_overrides,
    )
  let route_input = build_route_edges_input(input, base_cache)
  @routing.route_edges(
    route_input,
    recover_slack_vnodes,
    (route_base, spline, spline_result) =>
      build_edge_layout_for_input(
        route_base,
        spline,
        spline_result,
        input,
      ),
    self_edge_label_height_pt_for_routes,
    self_edge_label_width_pt,
    edge_port_label_pos,
  )
}
