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
  vnode_info : EdgeVnodeInfo
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
  head_port_metrics : HeadPortMetrics
  flat_label_edge_vnodes : Map[String, String]
  routing_context : @routing.RoutingContext
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: ordered-edge routing context captures pass-stable routing
/// inputs, including prepass-derived ordering/grouping state.
priv struct OrderedEdgeRoutingContext {
  input : EdgeRoutingPassInput
  regular_pass_input : @routing.RegularPassInput
  base_cache : Map[Int, EdgeRouteBase]
  prepass : @routing.RoutePrepassState
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
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
fn build_edge_layout_for_context(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  @routing.build_edge_layout(
    base,
    spline,
    spline_result,
    {
      ranks: context.input.ranks,
      rank_y: context.input.rank_y,
      vnode_info: context.input.vnode_info,
      vnode_positions: context.input.vnode_positions,
      has_clusters: context.input.has_clusters,
      nodesep_pt: context.input.nodesep_pt,
      flat_label_edge_vnodes: context.input.flat_label_edge_vnodes,
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
fn build_regular_pass_input(
  input : EdgeRoutingPassInput,
) -> @routing.RegularPassInput {
  {
    spline_mode: spline_mode_for_regular_pass(input.splines),
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
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
  }
}

///|
/// Graphviz parity: edge route bases are cached per edge id before routing.
/// Do not change behavior without updating fixtures/tests.
fn build_route_base_cache(
  input : EdgeRoutingPassInput,
  sameport_overrides : SameportOverrides,
) -> Map[Int, EdgeRouteBase] {
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
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
/// Graphviz parity: ordered-edge routing context construction keeps prepass
/// setup (sameport/base-cache/order/group/bounds) in one place before routing.
/// Do not change behavior without updating fixtures/tests.
fn build_ordered_edge_routing_context(
  input : EdgeRoutingPassInput,
) -> OrderedEdgeRoutingContext {
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
  let prepass =
    @routing.build_route_prepass_state(
      input.edges,
      base_cache,
      input.splines == SplinesMode::Spline,
      input.ranks,
      input.routing_context.order_index,
      input.routing_context.path_order_index,
      input.positions,
      input.vnode_positions,
      input.sizes,
      input.vnode_info.vnode_sizes,
      input.x_groups,
    )
  let self_edge_groups = @routing.collect_self_edge_groups(input.edges)
  let regular_pass_input = build_regular_pass_input(input)
  {
    input,
    regular_pass_input,
    base_cache,
    prepass,
    self_edge_groups,
  }
}

///|
/// Graphviz parity: flat-adjacent routed spline reuse keeps makeSimpleFlat
/// branch before self-edge/regular-edge routing.
/// Do not change behavior without updating fixtures/tests.
fn maybe_build_flat_adjacent_layout(
  edge_id : Int,
  base : EdgeRouteBase,
  context : OrderedEdgeRoutingContext,
  state : OrderedEdgeRoutingState,
) -> Bool {
  match context.prepass.flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        @routing.build_flat_adjacent_layout(
          base,
          bezier,
          (route_base, spline, spline_result) =>
            build_edge_layout_for_context(
              route_base,
              spline,
              spline_result,
              context,
            ),
        )
      state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
/// Graphviz parity: self-edge route cache reuse + self-edge layout finalize path.
/// Do not change behavior without updating fixtures/tests.
fn maybe_build_self_edge_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  context : OrderedEdgeRoutingContext,
  state : OrderedEdgeRoutingState,
) -> Bool {
  let edge_id = edge.id()
  let input = context.input
  let route = @routing.self_edge_route_for_edge(
    edge,
    context.self_edge_groups,
    context.base_cache,
    input.nodesep_pt,
    input.rank_y,
    state.self_edge_routes,
    self_edge_label_height_pt_for_routes,
    self_edge_label_width_pt,
  )
  match route {
    Some(route) => {
      let edge_layout =
        @routing.build_self_edge_layout(
          base,
          route,
          (route_base, spline, spline_result) =>
            build_edge_layout_for_context(
              route_base,
              spline,
              spline_result,
              context,
            ),
        )
      state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
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
  if maybe_build_flat_adjacent_layout(
    edge_id,
    base,
    context,
    state,
  ) {
    return ()
  }
  if maybe_build_self_edge_layout(
    edge,
    base,
    context,
    state,
  ) {
    return ()
  }
  @routing.build_regular_layouts_for_edge(
    edge_id,
    edge,
    base,
    context.regular_pass_input,
    context.prepass.path_left_bound,
    context.prepass.path_right_bound,
    context.prepass.recover_edge_id_for_routing,
    context.prepass.regular_parallel_groups,
    context.base_cache,
    state.recovered_slack_keys,
    state.edges_out_by_id,
    recover_slack_vnodes,
    (route_base, spline, spline_result) =>
      build_edge_layout_for_context(
        route_base,
        spline,
        spline_result,
        context,
      ),
  )
}

///|
/// Graphviz parity: ordered-edge routing loop keeps mutable self-edge and
/// recover-slack state shared across edges in pass order.
/// Do not change behavior without updating fixtures/tests.
fn route_ordered_edges(
  context : OrderedEdgeRoutingContext,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let state : OrderedEdgeRoutingState = {
    recovered_slack_keys: Map::new(),
    self_edge_routes: Map::new(),
    edges_out_by_id,
  }
  for edge in context.prepass.ordered_edges {
    route_ordered_edge(
      edge,
      context,
      state,
    )
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  input : EdgeRoutingPassInput,
) -> Array[DotLayoutEdge] {
  let ordered_edge_routing_context =
    build_ordered_edge_routing_context(input)
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  route_ordered_edges(
    ordered_edge_routing_context,
    edges_out_by_id,
  )
  @routing.finalize_routed_edges(
    input.edges,
    input.ranks,
    edges_out_by_id,
    edge_port_label_pos,
  )
}
