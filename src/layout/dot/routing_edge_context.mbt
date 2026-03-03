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
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: ordered-edge routing context captures pass-stable routing
/// inputs, including prepass-derived ordering/grouping state.
priv struct OrderedEdgeRoutingContext {
  input : EdgeRoutingPassInput
  base_cache : Map[Int, EdgeRouteBase]
  prepass : RoutePrepassState
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
/// Graphviz parity: edge route bases are cached per edge id before routing.
/// Do not change behavior without updating fixtures/tests.
fn build_route_base_cache(
  edges : Array[@cgraph.Edge],
  build_base : (@cgraph.Edge) -> EdgeRouteBase,
) -> Map[Int, EdgeRouteBase] {
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in edges {
    let edge_id = edge.id()
    if base_cache.get(edge_id) is None {
      base_cache[edge_id] = build_base(edge)
    }
  }
  base_cache
}

///|
/// Graphviz parity: self-edge routing groups reuse edge_parallel_key classes.
/// Do not change behavior without updating fixtures/tests.
fn self_edge_group_key(edge : @cgraph.Edge) -> String {
  @edge_ops.edge_parallel_key(
    edge.tail().name(),
    edge.head().name(),
    edge.tail_port(),
    edge.head_port(),
  )
}

///|
/// Graphviz parity: self-edge groups share generated loop routes in one pass.
/// Do not change behavior without updating fixtures/tests.
fn collect_self_edge_groups(
  edges : Array[@cgraph.Edge],
) -> Map[String, Array[@cgraph.Edge]] {
  let self_edge_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge.tail().name() != edge.head().name() {
      continue
    }
    let key = self_edge_group_key(edge)
    match self_edge_groups.get(key) {
      Some(list) => list.push(edge)
      None => self_edge_groups[key] = [edge]
    }
  }
  self_edge_groups
}

///|
/// Graphviz parity: self-edge route cache reuse keeps grouped self loops
/// synchronized before layout emission.
/// Do not change behavior without updating fixtures/tests.
fn ensure_self_edge_routes(
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[SelfEdgeRoute],
) -> Unit {
  let edge_id = edge.id()
  if self_edge_routes.get(edge_id) is Some(_) {
    return ()
  }
  let key = self_edge_group_key(edge)
  match self_edge_groups.get(key) {
    Some(group_edges) => {
      let group_bases : Array[EdgeRouteBase] = []
      for grouped in group_edges {
        let gid = grouped.id()
        let gbase = match base_cache.get(gid) {
          Some(value) => value
          None => return ()
        }
        group_bases.push(gbase)
      }
      let group_routes =
        build_group_routes(
          group_edges,
          group_bases,
          nodesep_pt,
          rank_y,
        )
      for i in 0..<group_edges.length() {
        self_edge_routes[group_edges[i].id()] = group_routes[i]
      }
    }
    None => ()
  }
}

///|
/// Graphviz parity: self-edge route lookup ensures grouped route cache first.
/// Do not change behavior without updating fixtures/tests.
fn self_edge_route_for_edge(
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[SelfEdgeRoute],
) -> SelfEdgeRoute? {
  if edge.tail().name() != edge.head().name() {
    return None
  }
  ensure_self_edge_routes(
    edge,
    self_edge_groups,
    base_cache,
    nodesep_pt,
    rank_y,
    self_edge_routes,
    build_group_routes,
  )
  self_edge_routes.get(edge.id())
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
  let build_base_for_edge =
    (edge : @cgraph.Edge) =>
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
  let base_cache =
    build_route_base_cache(
      input.edges,
      build_base_for_edge,
    )
  let prepass =
    build_route_prepass_state(
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
  let self_edge_groups = collect_self_edge_groups(input.edges)
  {
    input,
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
        build_flat_adjacent_layout(
          base,
          bezier,
          context,
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
  let route = self_edge_route_for_edge(
    edge,
    context.self_edge_groups,
    context.base_cache,
    input.nodesep_pt,
    input.rank_y,
    state.self_edge_routes,
    build_self_edge_routes,
  )
  match route {
    Some(route) => {
      let edge_layout =
        build_self_edge_layout(
          base,
          route,
          context,
        )
      state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
priv struct RegularSplineLayoutResult {
  edge_layout : DotLayoutEdge
  spline_result : EdgeSplineResult
}

///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_edge(base : EdgeRouteBase) -> Array[String] {
  if base.tail_rank <= base.head_rank {
    base.vnodes.copy()
  } else {
    let reversed : Array[String] = []
    let mut idx = base.vnodes.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(base.vnodes[idx])
    }
    reversed
  }
}

///|
/// Graphviz parity: pathplan recover_slack runs with limitBoxes before vnode updates.
/// Do not change behavior without updating fixtures/tests.
fn recover_pathplan_slack(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, @dot_shared.NodeSize],
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_by_key : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
  recover_slack_vnodes : (
    @cgraph.Edge,
    Array[String],
    Array[@geom.Rect],
    Map[String, Int],
    Map[String, Int],
    Map[Int, Double],
    Map[String, @geom.Point],
    Map[String, @dot_shared.NodeSize],
    @routesplines.PathAdjacency,
  ) -> Unit,
) -> Unit {
  if !spline_result.using_pathplan {
    return ()
  }
  let recover_key = recover_slack_key_for_edge(edge)
  match recover_edge_id_by_key.get(recover_key) {
    Some(recover_edge_id) =>
      if recover_edge_id != edge.id() {
        return ()
      }
    None => ()
  }
  if recovered_slack_keys.get(recover_key) is Some(_) {
    return ()
  }
  if spline_result.pathplan_segments.length() > 0 {
    let mut did_recover = false
    // Graphviz parity: straight_path recovers slack per routed segment.
    for segment in spline_result.pathplan_segments {
      if segment.vnodes.length() == 0 || segment.boxes.length() == 0 {
        continue
      }
      let ordered_vnodes =
        if base.tail_rank <= base.head_rank {
          segment.vnodes.copy()
        } else {
          let reversed : Array[String] = []
          let mut idx = segment.vnodes.length()
          while idx > 0 {
            idx = idx - 1
            reversed.push(segment.vnodes[idx])
          }
          reversed
        }
      recover_slack_vnodes(
        edge,
        ordered_vnodes,
        segment.boxes,
        ranks,
        vnode_ranks,
        rank_y,
        vnode_positions,
        vnode_sizes,
        path_adjacency,
      )
      did_recover = true
    }
    if did_recover {
      recovered_slack_keys[recover_key] = true
    }
    return ()
  }
  if spline_result.pathplan_boxes.length() == 0 ||
    spline_result.raw_bezier.length() < 4 {
    return ()
  }
  let limited_boxes =
    @routesplines.limit_boxes_for_spline(
      spline_result.pathplan_boxes,
      spline_result.raw_bezier,
      fallback_polyline=spline_result.pathplan_points,
    )
  let ordered_vnodes = ordered_vnodes_for_edge(base)
  recover_slack_vnodes(
    edge,
    ordered_vnodes,
    limited_boxes,
    ranks,
    vnode_ranks,
    rank_y,
    vnode_positions,
    vnode_sizes,
    path_adjacency,
  )
  recovered_slack_keys[recover_key] = true
}

///|
/// Graphviz parity: regular-edge routing keeps build/finalize/recover_slack flow.
/// Do not change behavior without updating fixtures/tests.
fn build_regular_spline_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  context : OrderedEdgeRoutingContext,
  recovered_slack_keys : Map[String, Bool],
) -> RegularSplineLayoutResult {
  let input = context.input
  let spline_result = build_edge_spline(
    base,
    input.splines,
    input.ranks,
    input.sizes,
    input.positions,
    input.vnode_positions,
    input.vnode_info,
    input.rank_y,
    input.rank_ht1,
    input.rank_ht2,
    input.x_groups,
    input.nodesep_pt,
    context.prepass.path_left_bound,
    context.prepass.path_right_bound,
    input.ranksep_pt,
    input.label_edge_counts,
    input.head_port_metrics,
    input.routing_context,
    input.enable_complex_tuning,
  )
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let spline = finalize_edge_spline(base, layout_spline_result)
  recover_pathplan_slack(
    edge,
    base,
    spline_result,
    input.ranks,
    input.vnode_info.vnode_ranks,
    input.rank_y,
    input.vnode_positions,
    input.vnode_info.vnode_sizes,
    input.routing_context.path_adjacency,
    context.prepass.recover_edge_id_for_routing,
    recovered_slack_keys,
    recover_slack_vnodes,
  )
  let layout =
    build_edge_layout(
      base,
      spline,
      layout_spline_result,
      context,
    )
  { edge_layout: layout, spline_result }
}

///|
/// Graphviz parity: regular-edge bezier reuse only expands from the first
/// ordered edge in each parallel vnode class.
/// Do not change behavior without updating fixtures/tests.
fn collect_parallel_reuse_siblings(
  edge : @cgraph.Edge,
  raw_bezier : Array[@geom.Point],
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]],
) -> Array[@cgraph.Edge] {
  if raw_bezier.length() == 0 {
    return []
  }
  let regular_key = @dot_shared.edge_vnode_key(edge)
  let group_edges = match regular_parallel_groups.get(regular_key) {
    Some(value) => value
    None => return []
  }
  if group_edges.length() <= 1 || group_edges[0].id() != edge.id() {
    return []
  }
  let siblings : Array[@cgraph.Edge] = []
  for group_edge in group_edges {
    if group_edge.id() != edge.id() {
      siblings.push(group_edge)
    }
  }
  siblings
}

///|
/// Graphviz parity: regular-edge sibling reuse expands only for selected
/// parallel vnode classes.
/// Do not change behavior without updating fixtures/tests.
fn apply_regular_parallel_reuse_layouts(
  edge : @cgraph.Edge,
  regular_layout : RegularSplineLayoutResult,
  context : OrderedEdgeRoutingContext,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let sibling_edges =
    collect_parallel_reuse_siblings(
      edge,
      regular_layout.spline_result.raw_bezier,
      context.prepass.regular_parallel_groups,
    )
  if sibling_edges.length() == 0 {
    return ()
  }
  for group_edge in sibling_edges {
    let group_edge_id = group_edge.id()
    let group_base = match context.base_cache.get(group_edge_id) {
      Some(value) => value
      None => continue
    }
    let group_layout =
      build_regular_bezier_layout(
        group_base,
        regular_layout.spline_result,
        context,
      )
    edges_out_by_id[group_edge_id] = group_layout
  }
}

///|
/// Graphviz parity: regular-edge routing keeps edge solve + parallel-reuse
/// expansion together after flat/self branches are skipped.
/// Do not change behavior without updating fixtures/tests.
fn build_regular_layouts_for_edge(
  edge_id : Int,
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  context : OrderedEdgeRoutingContext,
  state : OrderedEdgeRoutingState,
) -> Unit {
  let regular_layout = build_regular_spline_layout(
    edge,
    base,
    context,
    state.recovered_slack_keys,
  )
  state.edges_out_by_id[edge_id] = regular_layout.edge_layout
  apply_regular_parallel_reuse_layouts(
    edge,
    regular_layout,
    context,
    state.edges_out_by_id,
  )
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
  build_regular_layouts_for_edge(
    edge_id,
    edge,
    base,
    context,
    state,
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
  finalize_routed_edges(input, edges_out_by_id)
}
