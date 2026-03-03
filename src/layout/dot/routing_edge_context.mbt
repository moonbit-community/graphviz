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

fn remap_port_label_pos(
  edge : @cgraph.Edge,
  splines : Array[@geom.Spline],
  label_attr : String,
  is_head : Bool,
  fallback : @geom.Point?,
) -> @geom.Point? {
  if !edge_attr_non_empty(edge, label_attr) {
    return None
  }
  if splines.length() == 0 {
    return fallback
  }
  let spline =
    if is_head {
      splines[splines.length() - 1]
    } else {
      splines[0]
    }
  match edge_port_label_pos(edge, spline, is_head) {
    Some(pos) => Some(pos)
    None => fallback
  }
}

///|
/// Graphviz parity: routed edge output stays in original edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn collect_input_order_edge_ids(
  edges : Array[@cgraph.Edge],
  has_layout : (Int) -> Bool,
) -> Array[Int] {
  let ordered_ids : Array[Int] = []
  for edge in edges {
    let edge_id = edge.id()
    if has_layout(edge_id) {
      ordered_ids.push(edge_id)
    }
  }
  ordered_ids
}

///|
fn remap_edge_layout_edge(
  edge : @cgraph.Edge,
  layout : DotLayoutEdge,
) -> DotLayoutEdge {
  let label_pos =
    if edge_attr_non_empty(edge, "label") {
      layout.label_pos
    } else {
      None
    }
  let head_label_pos = remap_port_label_pos(
    edge,
    layout.splines,
    "headlabel",
    true,
    layout.head_label_pos,
  )
  let tail_label_pos = remap_port_label_pos(
    edge,
    layout.splines,
    "taillabel",
    false,
    layout.tail_label_pos,
  )
  let xlabel_pos =
    if edge_attr_non_empty(edge, "xlabel") {
      layout.xlabel_pos
    } else {
      None
    }
  {
    edge,
    splines: layout.splines,
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
/// Graphviz parity: duplicate regular-edge remap groups follow one-direction
/// parallel classes only.
/// Do not change behavior without updating fixtures/tests.
fn collect_parallel_remap_edge_ids(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
) -> Array[Array[Int]] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = ranks.get(tail).unwrap_or_default()
    let head_rank = ranks.get(head).unwrap_or_default()
    if tail_rank == head_rank {
      continue
    }
    let key = @edge_ops.edge_parallel_group_key(edge)
    let sameport_mark = @edge_ops.edge_has_sameport_mark(edge)
    let dir_key = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let sameport_tag = if sameport_mark { "sameport" } else { "plain" }
    let direction_key =
      "\{tail}|\{@dot_shared.port_key(edge.tail_port())}|\{head}|\{@dot_shared.port_key(edge.head_port())}|\{dir_key}|\{sameport_tag}"
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  let remap_groups : Array[Array[Int]] = []
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    remap_groups.push(ids)
  }
  remap_groups
}

///|
/// Graphviz parity: remap groups are applied only when all grouped ids already
/// have routed layouts.
/// Do not change behavior without updating fixtures/tests.
fn collect_complete_parallel_remap_groups(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  has_layout : (Int) -> Bool,
) -> Array[Array[Int]] {
  let complete_groups : Array[Array[Int]] = []
  for ids in collect_parallel_remap_edge_ids(edges, ranks) {
    let mut all_present = true
    for edge_id in ids {
      if !has_layout(edge_id) {
        all_present = false
        break
      }
    }
    if all_present {
      complete_groups.push(ids)
    }
  }
  complete_groups
}

///|
priv struct ParallelRemapAssignment {
  target_edge_id : Int
  source_edge_id : Int
}

///|
/// Graphviz parity: each parallel remap group applies reversed source slots
/// to ascending target ids.
/// Do not change behavior without updating fixtures/tests.
fn build_parallel_remap_assignments(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  has_layout : (Int) -> Bool,
) -> Array[ParallelRemapAssignment] {
  let assignments : Array[ParallelRemapAssignment] = []
  for ids in collect_complete_parallel_remap_groups(edges, ranks, has_layout) {
    let mut out_idx = 0
    let mut src_idx = ids.length()
    while out_idx < ids.length() {
      src_idx = src_idx - 1
      assignments.push({
        target_edge_id: ids[out_idx],
        source_edge_id: ids[src_idx],
      })
      out_idx = out_idx + 1
    }
  }
  assignments
}

///|
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
fn remap_parallel_edge_layouts(
  input : EdgeRoutingPassInput,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let assignments =
    build_parallel_remap_assignments(
      input.edges,
      input.ranks,
      (edge_id) => edges_out_by_id.get(edge_id) is Some(_),
    )
  let remap_snapshot : Map[Int, DotLayoutEdge] = Map::new()
  for assignment in assignments {
    match edges_out_by_id.get(assignment.target_edge_id) {
      Some(layout) => remap_snapshot[assignment.target_edge_id] = layout
      None => ()
    }
    match edges_out_by_id.get(assignment.source_edge_id) {
      Some(layout) => remap_snapshot[assignment.source_edge_id] = layout
      None => ()
    }
  }
  for assignment in assignments {
    let target_layout = match remap_snapshot.get(assignment.target_edge_id) {
      Some(value) => value
      None => continue
    }
    let source_layout = match remap_snapshot.get(assignment.source_edge_id) {
      Some(value) => value
      None => continue
    }
    edges_out_by_id[assignment.target_edge_id] =
      remap_edge_layout_edge(target_layout.edge, source_layout)
  }
}

///|
/// Graphviz parity: final routed edge output keeps remap-then-input-order flow.
/// Do not change behavior without updating fixtures/tests.
fn finalize_routed_edges(
  input : EdgeRoutingPassInput,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Array[DotLayoutEdge] {
  remap_parallel_edge_layouts(input, edges_out_by_id)
  let ordered_output_edge_ids =
    collect_input_order_edge_ids(
      input.edges,
      (edge_id) => edges_out_by_id.get(edge_id) is Some(_),
    )
  let edges_out : Array[DotLayoutEdge] = []
  for edge_id in ordered_output_edge_ids {
    match edges_out_by_id.get(edge_id) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}
///|
priv struct BezierLayoutSplineResult {
  final_spline : @geom.Spline
  layout_spline_result : EdgeSplineResult
}

///|
/// Graphviz parity: bezier route rendering follows
/// build_bezier_points_spline -> edge_spline_result_for_bezier ->
/// rebuild_spline_for_render -> finalize_edge_spline.
/// Do not change behavior without updating fixtures/tests.
fn build_bezier_layout_spline_result(
  base : EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
) -> BezierLayoutSplineResult {
  let spline =
    build_bezier_points_spline(
      base,
      raw_bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      tail_swap,
      head_swap,
    )
  let spline_result =
    edge_spline_result_for_bezier(
      spline,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
    )
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let final_spline = finalize_edge_spline(base, layout_spline_result)
  { final_spline, layout_spline_result }
}

///|
fn build_bezier_layout_edge(
  base : EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let bezier_layout_result =
    build_bezier_layout_spline_result(
      base,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
      tail_swap,
      head_swap,
    )
  build_edge_layout(
    base,
    bezier_layout_result.final_spline,
    bezier_layout_result.layout_spline_result,
    context,
  )
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_layout(
  base : EdgeRouteBase,
  route : SelfEdgeRoute,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let mut edge_layout =
    build_bezier_layout_edge(
      base,
      route.points,
      0.0,
      false,
      false,
      false,
      context,
    )
  match route.label_pos {
    Some(pos) =>
      edge_layout = {
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos: Some(pos),
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      }
    None => ()
  }
  edge_layout
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn build_flat_adjacent_layout(
  base : EdgeRouteBase,
  bezier : Array[@geom.Point],
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    bezier,
    0.0,
    false,
    base.swap_ends,
    base.swap_ends,
    context,
  )
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
fn build_regular_bezier_layout(
  base : EdgeRouteBase,
  shared_spline_result : EdgeSplineResult,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    shared_spline_result.raw_bezier,
    shared_spline_result.label_pad_boost,
    shared_spline_result.apply_dotted_adjustment,
    base.swap_ends,
    base.swap_ends,
    context,
  )
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  context : OrderedEdgeRoutingContext,
) -> DotLayoutEdge {
  let input = context.input
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, input.ranks)
  let label_rank_y =
    edge_label_rank_y(edge, input.ranks, input.rank_y)
  let mid_label_metrics = edge_mid_label_metrics(edge)
  let label_rank_x = match label_rank_info {
    Some(info) =>
      if info.span > 1 {
        edge_label_rank_x(
          edge,
          info.label_rank,
          input.vnode_info.vnode_ranks,
          input.vnode_info.edge_vnodes,
          input.vnode_positions,
        )
      } else {
        None
      }
    None => None
  }
  let apply_label_pad = input.has_clusters
  let default_label_pos =
    () =>
      edge_label_pos(
        edge,
        spline,
        base.out_tail_clip,
        base.out_head_clip,
        base.layout_rankdir,
        label_rank_y,
        label_rank_x,
        apply_label_pad,
        input.nodesep_pt,
        spline_result.label_pad_boost,
      )
  let flat_simple_or_default =
    () =>
      match mid_label_metrics {
        Some(metrics) =>
          Some(
            flat_edge_label_pos_simple(
              base.out_tail_pos,
              base.out_head_pos,
              base.out_tail_size.right_pt,
              base.out_head_size.left_pt,
              metrics.height,
            ),
          )
        None => default_label_pos()
      }
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, mid_label_metrics) {
          (Some(rank_x), Some(rank_y), Some(metrics)) => {
            Some(
              edge_label_pos_from_vnode(
                @edge_spline.point(rank_x, rank_y),
                metrics.width,
                metrics.height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match input.flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
                Some(vnode_name) =>
                  match input.vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None => flat_simple_or_default()
                  }
                None => flat_simple_or_default()
              }
            } else {
              default_label_pos()
            }
        }
      }
    None => None
  }
  let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, false)
      }
    None => None
  }
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}
///|
fn self_edge_label_height_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
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
priv struct RankBounds {
  min_rank : Int
  max_rank : Int
}

///|
fn rank_bounds(rank_y : Map[Int, Double]) -> RankBounds {
  let mut min_rank = 0
  let mut max_rank = 0
  let mut seen = false
  for rank, _ in rank_y {
    if !seen {
      min_rank = rank
      max_rank = rank
      seen = true
    } else {
      if rank < min_rank { min_rank = rank }
      if rank > max_rank { max_rank = rank }
    }
  }
  { min_rank, max_rank }
}

///|
fn self_edge_rank_spacing(
  rank : Int,
  rank_y : Map[Int, Double],
  node_y : Double,
  node_height : Double,
  min_rank : Int,
  max_rank : Int,
) -> Double {
  if min_rank == max_rank {
    return node_height
  }
  if rank == max_rank {
    if rank > min_rank {
      match rank_y.get(rank - 1) {
        Some(prev) => Double::abs(prev - node_y)
        None => node_height
      }
    } else {
      node_height
    }
  } else if rank == min_rank {
    match rank_y.get(rank + 1) {
      Some(next) => Double::abs(node_y - next)
      None => node_height
    }
  } else {
    let up = match rank_y.get(rank - 1) {
      Some(prev) => Double::abs(prev - node_y)
      None => node_height
    }
    let down = match rank_y.get(rank + 1) {
      Some(next) => Double::abs(node_y - next)
      None => node_height
    }
    min_double(up, down)
  }
}

///|
fn convert_sides_to_points(tail_side : Int, head_side : Int) -> Int {
  let vertices : Array[Int] = [12, 4, 6, 2, 3, 1, 9, 8]
  let pair_a : Array[Array[Int]] = [
    [11, 12, 13, 14, 15, 16, 17, 18],
    [21, 22, 23, 24, 25, 26, 27, 28],
    [31, 32, 33, 34, 35, 36, 37, 38],
    [41, 42, 43, 44, 45, 46, 47, 48],
    [51, 52, 53, 54, 55, 56, 57, 58],
    [61, 62, 63, 64, 65, 66, 67, 68],
    [71, 72, 73, 74, 75, 76, 77, 78],
    [81, 82, 83, 84, 85, 86, 87, 88],
  ]
  let mut tail_i = -1
  let mut head_i = -1
  for i in 0..<vertices.length() {
    if tail_side == vertices[i] {
      tail_i = i
      break
    }
  }
  for i in 0..<vertices.length() {
    if head_side == vertices[i] {
      head_i = i
      break
    }
  }
  if tail_i < 0 || head_i < 0 {
    0
  } else {
    pair_a[tail_i][head_i]
  }
}

///|
fn self_edge_routes_top(
  edges : Array[@cgraph.Edge],
  base0 : EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[SelfEdgeRoute] {
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let stepx = max_double(nodesep_pt / 2.0 / cnt_f, 2.0)
  let stepy = sizey_param
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let sgn = if tp.x >= hp.x { 1.0 } else { -1.0 }
  let lw = base0.tail_size.left_pt
  let rw = base0.tail_size.right_pt
  let mut dx = 0.0
  match point_pair {
    15 => {
      dx = sgn * (rw - (hp.x - np.x) + stepx)
    }
    38 => {
      dx = sgn * (lw - (np.x - hp.x) + stepx)
    }
    41 | 48 => {
      dx = sgn * (rw - (tp.x - np.x) + stepx)
    }
    14 | 37 | 47 | 51 | 57 | 58 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 3.0)
    }
    73 => {
      dx = sgn * (lw - (np.x - tp.x) + stepx)
    }
    83 => {
      dx = sgn * (lw - (np.x - tp.x))
    }
    84 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 2.0 + stepx)
    }
    74 | 75 | 85 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 2.0 + 2.0 * stepx)
    }
    _ => ()
  }
  let mut dy = base0.tail_size.height_pt / 2.0
  let mut ty = min_double(dy, 3.0 * (np.y + dy - tp.y))
  let mut hy = min_double(dy, 3.0 * (np.y + dy - hp.y))
  let routes : Array[SelfEdgeRoute] = []
  for i in 0..<cnt {
    let edge = edges[i]
    dy = dy + stepy
    ty = ty + stepy
    hy = hy + stepy
    dx = dx + sgn * stepx
    let points = [
      tp,
      @edge_spline.point(tp.x + dx, tp.y + ty / 3.0),
      @edge_spline.point(tp.x + dx, np.y + dy),
      @edge_spline.point((tp.x + hp.x) / 2.0, np.y + dy),
      @edge_spline.point(hp.x - dx, np.y + dy),
      @edge_spline.point(hp.x - dx, hp.y + hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(@edge_spline.point(np.x, np.y + dy + label_height / 2.0))
      if label_height > stepy {
        dy = dy + (label_height - stepy)
      }
    }
    routes.push({ points, label_pos })
  }
  routes
}

///|
fn self_edge_routes_bottom(
  edges : Array[@cgraph.Edge],
  base0 : EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[SelfEdgeRoute] {
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let stepx = max_double(nodesep_pt / 2.0 / cnt_f, 2.0)
  let stepy = sizey_param
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let mut sgn = if tp.x >= hp.x { 1.0 } else { -1.0 }
  if point_pair == 67 {
    sgn = -sgn
  }
  let mut dx = 0.0
  let mut dy = base0.tail_size.height_pt / 2.0
  let mut ty = min_double(dy, 3.0 * (tp.y + dy - np.y))
  let mut hy = min_double(dy, 3.0 * (hp.y + dy - np.y))
  let routes : Array[SelfEdgeRoute] = []
  for i in 0..<cnt {
    let edge = edges[i]
    dy = dy + stepy
    ty = ty + stepy
    hy = hy + stepy
    dx = dx + sgn * stepx
    let points = [
      tp,
      @edge_spline.point(tp.x + dx, tp.y - ty / 3.0),
      @edge_spline.point(tp.x + dx, np.y - dy),
      @edge_spline.point((tp.x + hp.x) / 2.0, np.y - dy),
      @edge_spline.point(hp.x - dx, np.y - dy),
      @edge_spline.point(hp.x - dx, hp.y - hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(@edge_spline.point(np.x, np.y - dy - label_height / 2.0))
      if label_height > stepy {
        dy = dy + (label_height - stepy)
      }
    }
    routes.push({ points, label_pos })
  }
  routes
}

///|
/// Graphviz parity: self-edge routing aligned to refs/graphviz/lib/common/splines.c.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_routes(
  edges : Array[@cgraph.Edge],
  bases : Array[EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
) -> Array[SelfEdgeRoute] {
  if edges.length() == 0 {
    return []
  }
  let base0 = bases[0]
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let all_sides =
    PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT
  let tail_side = if base0.tail_port_side == 0 {
    match base0.tail_port {
      Some(value) =>
        if value.compass is None {
          // Graphviz parity: side-less label ports on self-edges still behave
          // like fully-open sides when dynamic side resolution is unavailable.
          all_sides
        } else {
          0
        }
      None => 0
    }
  } else {
    base0.tail_port_side
  }
  let head_side = if base0.head_port_side == 0 {
    match base0.head_port {
      Some(value) =>
        if value.compass is None {
          all_sides
        } else {
          0
        }
      None => 0
    }
  } else {
    base0.head_port_side
  }
  let tail_defined = @dot_shared.port_is_explicit(base0.tail_port)
  let head_defined = @dot_shared.port_is_explicit(base0.head_port)
  let bounds = rank_bounds(rank_y)
  let sizey =
    self_edge_rank_spacing(
      base0.tail_rank,
      rank_y,
      np.y,
      base0.tail_size.height_pt,
      bounds.min_rank,
      bounds.max_rank,
    )
  let sizey_param = sizey / 2.0
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let same_side = tail_side == head_side
  let tail_tb = (tail_side & (PORT_SIDE_TOP | PORT_SIDE_BOTTOM)) != 0
  let go_right =
    (!tail_defined && !head_defined) ||
      (
        (tail_side & PORT_SIDE_LEFT) == 0 &&
          (head_side & PORT_SIDE_LEFT) == 0 &&
          (!same_side || !tail_tb)
      )
  let uses_left =
    (tail_side & PORT_SIDE_LEFT) != 0 || (head_side & PORT_SIDE_LEFT) != 0
  let uses_right =
    (tail_side & PORT_SIDE_RIGHT) != 0 || (head_side & PORT_SIDE_RIGHT) != 0
  if go_right {
    let stepx = nodesep_pt
    let stepy = max_double(sizey_param / 2.0 / cnt_f, 2.0)
    let mut sgn = if tp.y >= hp.y { 1.0 } else { -1.0 }
    let point_pair = convert_sides_to_points(tail_side, head_side)
    if (point_pair == 32 || point_pair == 65) && tp.y == hp.y {
      sgn = -sgn
    }
    let mut dx = base0.tail_size.right_pt
    let mut dy = 0.0
    let mut tx = min_double(dx, 3.0 * (np.x + dx - tp.x))
    let mut hx = min_double(dx, 3.0 * (np.x + dx - hp.x))
    let routes : Array[SelfEdgeRoute] = []
    for i in 0..<cnt {
      let edge = edges[i]
      dx = dx + stepx
      tx = tx + stepx
      hx = hx + stepx
      dy = dy + sgn * stepy
      let points = [
        tp,
        @edge_spline.point(tp.x + tx / 3.0, tp.y + dy),
        @edge_spline.point(np.x + dx, tp.y + dy),
        @edge_spline.point(np.x + dx, (tp.y + hp.y) / 2.0),
        @edge_spline.point(np.x + dx, hp.y - dy),
        @edge_spline.point(hp.x + hx / 3.0, hp.y - dy),
        hp,
      ]
      let mut label_pos : @geom.Point? = None
      let label_width = self_edge_label_width_pt(edge, base0.rankdir)
      if label_width > 0.0 {
        label_pos = Some(@edge_spline.point(np.x + dx + label_width / 2.0, np.y))
        if label_width > stepx {
          dx = dx + (label_width - stepx)
        }
      }
      routes.push({ points, label_pos })
    }
    return routes
  }
  if uses_left {
    if uses_right {
      return self_edge_routes_top(
        edges,
        base0,
        nodesep_pt,
        sizey_param,
        convert_sides_to_points(tail_side, head_side),
      )
    } else {
      let stepx = nodesep_pt
      let stepy = max_double(sizey_param / 2.0 / cnt_f, 2.0)
      let mut sgn = if tp.y >= hp.y { 1.0 } else { -1.0 }
      let point_pair = convert_sides_to_points(tail_side, head_side)
      if (point_pair == 12 || point_pair == 67) && tp.y == hp.y {
        sgn = -sgn
      }
      let mut dx = base0.tail_size.left_pt
      let mut dy = 0.0
      let mut tx = min_double(dx, 3.0 * (tp.x + dx - np.x))
      let mut hx = min_double(dx, 3.0 * (hp.x + dx - np.x))
      let routes : Array[SelfEdgeRoute] = []
      for i in 0..<cnt {
        let edge = edges[i]
        dx = dx + stepx
        tx = tx + stepx
        hx = hx + stepx
        dy = dy + sgn * stepy
        let points = [
          tp,
          @edge_spline.point(tp.x - tx / 3.0, tp.y + dy),
          @edge_spline.point(np.x - dx, tp.y + dy),
          @edge_spline.point(np.x - dx, (tp.y + hp.y) / 2.0),
          @edge_spline.point(np.x - dx, hp.y - dy),
          @edge_spline.point(hp.x - hx / 3.0, hp.y - dy),
          hp,
        ]
        let mut label_pos : @geom.Point? = None
        let label_width = self_edge_label_width_pt(edge, base0.rankdir)
        if label_width > 0.0 {
          label_pos = Some(@edge_spline.point(np.x - dx - label_width / 2.0, np.y))
          if label_width > stepx {
            dx = dx + (label_width - stepx)
          }
        }
        routes.push({ points, label_pos })
      }
      return routes
    }
  }
  let point_pair = convert_sides_to_points(tail_side, head_side)
  if (tail_side & PORT_SIDE_TOP) != 0 {
    return self_edge_routes_top(
      edges,
      base0,
      nodesep_pt,
      sizey_param,
      point_pair,
    )
  }
  if (tail_side & PORT_SIDE_BOTTOM) != 0 {
    return self_edge_routes_bottom(
      edges,
      base0,
      nodesep_pt,
      sizey_param,
      point_pair,
    )
  }
  self_edge_routes_top(edges, base0, nodesep_pt, sizey_param, point_pair)
}
///|
const ROUTE_EDGE_REGULAR : Int = 1
///|
const ROUTE_EDGE_FLAT : Int = 2
///|
const ROUTE_EDGE_SELF_PORT : Int = 4
///|
const ROUTE_EDGE_SELF_NOPORT : Int = 8
///|
const ROUTE_GRAPH_MAIN : Int = 64
///|
const ROUTE_GRAPH_AUX : Int = 128

///|
fn edge_route_type(base : EdgeRouteBase) -> Int {
  if base.orig_tail_name == base.orig_head_name {
    if @dot_shared.port_is_explicit(base.tail_port) ||
      @dot_shared.port_is_explicit(base.head_port) {
      ROUTE_EDGE_SELF_PORT
    } else {
      ROUTE_EDGE_SELF_NOPORT
    }
  } else if base.is_flat_edge {
    ROUTE_EDGE_FLAT
  } else {
    ROUTE_EDGE_REGULAR
  }
}

///|
fn edge_route_graph_type(edge_type : Int) -> Int {
  if edge_type == ROUTE_EDGE_REGULAR {
    ROUTE_GRAPH_MAIN
  } else {
    ROUTE_GRAPH_AUX
  }
}

///|
fn cmp_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn cmp_double(a : Double, b : Double) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn port_cmp(
  a_defined : Bool,
  a_pos : @geom.Point,
  b_defined : Bool,
  b_pos : @geom.Point,
) -> Int {
  if !b_defined {
    if a_defined { 1 } else { 0 }
  } else if !a_defined {
    -1
  } else if a_pos.x < b_pos.x {
    -1
  } else if a_pos.x > b_pos.x {
    1
  } else if a_pos.y < b_pos.y {
    -1
  } else if a_pos.y > b_pos.y {
    1
  } else {
    0
  }
}

///|
priv struct EdgePortCmpInfo {
  tail_defined : Bool
  tail_pos : @geom.Point
  head_defined : Bool
  head_pos : @geom.Point
}

///|
fn edge_port_cmp_info(
  base : EdgeRouteBase,
  edge_type : Int,
  order_index : Map[String, Int],
) -> EdgePortCmpInfo {
  let tail_anchor =
    if base.swap_ends { base.head_anchor } else { base.tail_anchor }
  let head_anchor =
    if base.swap_ends { base.tail_anchor } else { base.head_anchor }
  let tail_pos = if base.swap_ends { base.head_pos } else { base.tail_pos }
  let head_pos = if base.swap_ends { base.tail_pos } else { base.head_pos }
  let tail_defined =
    if base.swap_ends { @dot_shared.port_is_explicit(base.head_port) } else {
      @dot_shared.port_is_explicit(base.tail_port)
    }
  let head_defined =
    if base.swap_ends { @dot_shared.port_is_explicit(base.tail_port) } else {
      @dot_shared.port_is_explicit(base.head_port)
    }
  let tail_rel =
    @edge_spline.point(tail_anchor.x - tail_pos.x, tail_anchor.y - tail_pos.y)
  let head_rel =
    @edge_spline.point(head_anchor.x - head_pos.x, head_anchor.y - head_pos.y)
  if edge_type == ROUTE_EDGE_FLAT {
    let tail_order = order_index.get(base.orig_tail_name).unwrap_or_default()
    let head_order = order_index.get(base.orig_head_name).unwrap_or_default()
    if tail_order > head_order {
      return {
        tail_defined: head_defined,
        tail_pos: head_rel,
        head_defined: tail_defined,
        head_pos: tail_rel,
      }
    }
  }
  {
    tail_defined,
    tail_pos: tail_rel,
    head_defined,
    head_pos: head_rel,
  }
}

///|
/// Graphviz parity: routing edge order matches dotgen/dotsplines.c edgecmp.
/// Do not change behavior without updating fixtures/tests.
fn route_edge_cmp(
  a : @cgraph.Edge,
  b : @cgraph.Edge,
  base_cache : Map[Int, EdgeRouteBase],
  order_index : Map[String, Int],
) -> Int {
  let base_a = match base_cache.get(a.id()) {
    Some(value) => value
    None => return 0
  }
  let base_b = match base_cache.get(b.id()) {
    Some(value) => value
    None => return 0
  }
  let type_a = edge_route_type(base_a)
  let type_b = edge_route_type(base_b)
  if type_a != type_b {
    return if type_a > type_b { -1 } else { 1 }
  }
  let rank_diff_a =
    if base_a.tail_rank >= base_a.head_rank {
      base_a.tail_rank - base_a.head_rank
    } else {
      base_a.head_rank - base_a.tail_rank
    }
  let rank_diff_b =
    if base_b.tail_rank >= base_b.head_rank {
      base_b.tail_rank - base_b.head_rank
    } else {
      base_b.head_rank - base_b.tail_rank
    }
  let rank_cmp = cmp_int(rank_diff_a, rank_diff_b)
  if rank_cmp != 0 {
    return rank_cmp
  }
  let xdiff_a = Double::abs(base_a.tail_pos.x - base_a.head_pos.x)
  let xdiff_b = Double::abs(base_b.tail_pos.x - base_b.head_pos.x)
  let xcmp = cmp_double(xdiff_a, xdiff_b)
  if xcmp != 0 {
    return xcmp
  }
  let id_a = a.id()
  let id_b = b.id()
  let id_cmp = cmp_int(id_a, id_b)
  if id_cmp != 0 {
    return id_cmp
  }
  let port_info_a = edge_port_cmp_info(base_a, type_a, order_index)
  let port_info_b = edge_port_cmp_info(base_b, type_b, order_index)
  let tail_cmp =
    port_cmp(
      port_info_a.tail_defined,
      port_info_a.tail_pos,
      port_info_b.tail_defined,
      port_info_b.tail_pos,
    )
  if tail_cmp != 0 {
    return tail_cmp
  }
  let head_cmp =
    port_cmp(
      port_info_a.head_defined,
      port_info_a.head_pos,
      port_info_b.head_defined,
      port_info_b.head_pos,
    )
  if head_cmp != 0 {
    return head_cmp
  }
  let graph_cmp = cmp_int(
    edge_route_graph_type(type_a),
    edge_route_graph_type(type_b),
  )
  if graph_cmp != 0 {
    return graph_cmp
  }
  if type_a == ROUTE_EDGE_FLAT {
    let label_a = edge_attr_or_empty(a, "label")
    let label_b = edge_attr_or_empty(b, "label")
    if label_a < label_b {
      return -1
    }
    if label_a > label_b {
      return 1
    }
  }
  cmp_int(id_a, id_b)
}

///|
/// Graphviz parity: edge routing pass order follows dot edgecmp.
/// Do not change behavior without updating fixtures/tests.
fn sorted_edges_for_routing(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  order_index : Map[String, Int],
) -> Array[@cgraph.Edge] {
  let ordered_edges = edges.copy()
  if ordered_edges.length() > 1 {
    ordered_edges.sort_by((a, b) => {
      route_edge_cmp(a, b, base_cache, order_index)
    })
  }
  ordered_edges
}

///|
fn cmp_edge_id(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn collect_flat_adjacent_beziers(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Map[Int, Array[@geom.Point]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge_is_self(edge) {
      continue
    }
    if edge_has_label(edge) {
      continue
    }
    if @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port()) {
      continue
    }
    if @edge_ops.edge_has_sameport_mark(edge) {
      continue
    }
    let tail_rank = match ranks.get(edge.tail().name()) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(edge.head().name()) {
      Some(value) => value
      None => continue
    }
    if tail_rank != head_rank {
      continue
    }
    let tail_order = match order_index.get(edge.tail().name()) {
      Some(value) => value
      None => continue
    }
    let head_order = match order_index.get(edge.head().name()) {
      Some(value) => value
      None => continue
    }
    let order_delta = tail_order - head_order
    if !(order_delta == 1 || order_delta == -1) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.has_side_anchor || base.has_vnodes ||
      !base.tail_clip_enabled || !base.head_clip_enabled {
      continue
    }
    let key =
      "\{edge.tail().name()}|\{@dot_shared.port_key(edge.tail_port())}|\{edge.head().name()}|\{@dot_shared.port_key(edge.head_port())}"
    match groups.get(key) {
      Some(list) => list.push(edge)
      None => groups[key] = [edge]
    }
  }
  let out : Map[Int, Array[@geom.Point]] = Map::new()
  for _key, group_edges in groups {
    if group_edges.length() <= 1 {
      continue
    }
    let rep = match base_cache.get(group_edges[0].id()) {
      Some(value) => value
      None => continue
    }
    let tx = rep.tail_anchor.x
    let ty = rep.tail_anchor.y
    let hx = rep.head_anchor.x
    let hy = rep.head_anchor.y
    let vx = hx - tx
    let vy = hy - ty
    let vlen = Double::sqrt(vx * vx + vy * vy)
    if vlen <= 0.0 {
      continue
    }
    let dir_x = vx / vlen
    let dir_y = vy / vlen
    let perp_x = -dir_y
    let perp_y = dir_x
    let base_span =
      if Double::abs(perp_x) >= Double::abs(perp_y) {
        rep.tail_size.width_pt
      } else {
        rep.tail_size.height_pt
      }
    let span = base_span
    if span <= 0.0 {
      continue
    }
    group_edges.sort_by((a, b) => cmp_edge_id(a.id(), b.id()))
    let count = group_edges.length()
    let base_one_third = @edge_spline.point(
      tx + (hx - tx) / 3.0,
      ty + (hy - ty) / 3.0,
    )
    let base_two_third = @edge_spline.point(
      tx + (hx - tx) * 2.0 / 3.0,
      ty + (hy - ty) * 2.0 / 3.0,
    )
    let denom =
      if count > 1 { Double::from_int(count - 1) } else { 1.0 }
    for i in 0..<count {
      let frac = Double::from_int(i) / denom
      let offset = -span / 2.0 + span * frac
      let shift = @edge_spline.point(perp_x * offset, perp_y * offset)
      let edge = group_edges[i]
      let edge_base = match base_cache.get(edge.id()) {
        Some(value) => value
        None => continue
      }
      let c1 = @edge_spline.point_add(base_one_third, shift)
      let c2 = @edge_spline.point_add(base_two_third, shift)
      out[edge.id()] = [
        edge_base.tail_anchor,
        c1,
        c2,
        edge_base.head_anchor,
      ]
    }
  }
  out
}

///|
/// Graphviz parity: recover_slack class keys collapse reverse-direction
/// unlabeled edges that share a class2 vnode chain.
fn recover_slack_key_for_edge(edge : @cgraph.Edge) -> String {
  let undirected = edge.tail().graph().kind() is @cgraph.GraphKind::Undirected
  if edge_has_label(edge) || !undirected {
    "vnode|\{@dot_shared.edge_vnode_key(edge)}"
  } else {
    "parallel|\{@edge_ops.edge_parallel_key(edge.tail().name(), edge.head().name(), edge.tail_port(), edge.head_port())}"
  }
}

///|
/// Graphviz parity: recover_slack for regular-edge classes uses the
/// center-most parallel member (tie: later edge id).
fn recover_regular_selection(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Int] {
  let selected_ids : Map[String, Int] = Map::new()
  let selected_scores : Map[String, Double] = Map::new()
  for edge in ordered_edges {
    if edge_is_self(edge) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = recover_slack_key_for_edge(edge)
    let score = Double::abs(base.parallel_offset)
    match selected_ids.get(key) {
      Some(current_id) => {
        let current_score = match selected_scores.get(key) {
          Some(value) => value
          None => score
        }
        if score < current_score ||
          (score == current_score && edge.id() > current_id) {
          selected_ids[key] = edge.id()
          selected_scores[key] = score
        }
      }
      None => {
        selected_ids[key] = edge.id()
        selected_scores[key] = score
      }
    }
  }
  selected_ids
}

///|
fn collect_parallel_groups(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in ordered_edges {
    if edge_has_label(edge) {
      continue
    }
    if edge_is_self(edge) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = @dot_shared.edge_vnode_key(edge)
    match groups.get(key) {
      Some(list) => list.push(edge)
      None => groups[key] = [edge]
    }
  }
  groups
}

///|
priv struct RegularRecoverRoutingPlan {
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  recover_edge_id_for_routing : Map[String, Int]
}

///|
/// Graphviz parity: recover_slack candidate selection runs before edge routing
/// and keeps regular classes aligned to ordered-edge grouping.
fn build_regular_recover_routing_plan(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> RegularRecoverRoutingPlan {
  let recover_edge_id_by_key =
    recover_regular_selection(ordered_edges, base_cache)
  let regular_parallel_groups =
    collect_parallel_groups(ordered_edges, base_cache)
  let recover_edge_id_for_routing : Map[String, Int] = Map::new()
  for key, edge_id in recover_edge_id_by_key {
    recover_edge_id_for_routing[key] = edge_id
  }
  for _key, group_edges in regular_parallel_groups {
    if group_edges.length() > 1 {
      let recover_key = recover_slack_key_for_edge(group_edges[0])
      recover_edge_id_for_routing[recover_key] = group_edges[0].id()
    }
  }
  { regular_parallel_groups, recover_edge_id_for_routing }
}

///|
priv struct RoutePrepassState {
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  ordered_edges : Array[@cgraph.Edge]
  recover_edge_id_for_routing : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  path_left_bound : Double
  path_right_bound : Double
}

///|
/// Graphviz parity: routing prepass order/group/bounds setup runs before the
/// edge routing loop and follows dot/pathplan sequencing.
/// Do not change behavior without updating fixtures/tests.
fn build_route_prepass_state(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  build_flat_adjacent_beziers : Bool,
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  path_order_index : Map[String, Int],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, @dot_shared.NodeSize],
  vnode_sizes : Map[String, @dot_shared.NodeSize],
  x_groups : Map[Int, Array[String]],
) -> RoutePrepassState {
  let flat_adjacent_simple_beziers =
    if build_flat_adjacent_beziers {
      collect_flat_adjacent_beziers(
        edges,
        base_cache,
        ranks,
        order_index,
      )
    } else {
      Map::new()
    }
  let path_bounds = @routesplines.pathplan_bounds(
    positions,
    vnode_positions,
    sizes,
    vnode_sizes,
    x_groups,
  )
  let ordered_edges =
    sorted_edges_for_routing(edges, base_cache, path_order_index)
  let regular_recover_plan =
    build_regular_recover_routing_plan(ordered_edges, base_cache)
  {
    flat_adjacent_simple_beziers,
    ordered_edges,
    recover_edge_id_for_routing: regular_recover_plan.recover_edge_id_for_routing,
    regular_parallel_groups: regular_recover_plan.regular_parallel_groups,
    path_left_bound: path_bounds.left,
    path_right_bound: path_bounds.right,
  }
}
///|
priv struct RoutingContext {
  order_index : Map[String, Int]
  path_order_index : Map[String, Int]
  path_adjacency : @routesplines.PathAdjacency
  pathplan_sizes : Map[String, NodeSize]
  pathplan_vnode_mval_sizes : Map[String, NodeSize]
  path_cluster_keys : Map[String, String]
  path_vnode_clusters : Map[String, String]
  parallel_offsets : Map[Int, Double]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
fn cluster_containing_point_or_empty(
  cluster_name : String,
  cluster_bboxes : Map[String, @geom.Rect],
  pos : @geom.Point,
) -> String {
  if cluster_name == "" {
    return ""
  }
  match cluster_bboxes.get(cluster_name) {
    Some(rect) =>
      if pos.x >= rect.llx && pos.x <= rect.urx &&
        pos.y >= rect.lly && pos.y <= rect.ury {
        cluster_name
      } else {
        ""
      }
    None => ""
  }
}

///|
fn build_path_vnode_clusters(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
  cluster_keys : Map[String, String],
  cluster_bboxes : Map[String, @geom.Rect],
) -> Map[String, String] {
  let vnode_clusters : Map[String, String] = Map::new()
  for edge in edges {
    let key = @dot_shared.edge_vnode_key(edge)
    let vnodes = edge_vnodes.get(key).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster = cluster_keys.get(edge.tail().name()).unwrap_or_default()
    let head_cluster = cluster_keys.get(edge.head().name()).unwrap_or_default()
    for vnode in vnodes {
      let pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster =
        cluster_containing_point_or_empty(
          tail_cluster,
          cluster_bboxes,
          pos,
        )
      if vnode_cluster == "" {
        vnode_cluster =
          cluster_containing_point_or_empty(
            head_cluster,
            cluster_bboxes,
            pos,
          )
      }
      vnode_clusters[vnode] = vnode_cluster
    }
  }
  vnode_clusters
}

///|
/// Graphviz parity: parallel offsets group by unordered endpoints/ports (set of
/// tail/head), and only for unlabeled edges (class2 merge_chain).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_parallel_offsets(
  edges : Array[@cgraph.Edge],
  edge_has_label_by_id : Map[Int, Bool],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  edge_reversed_by_id : Map[Int, Bool],
  cluster_keys : Map[String, String],
) -> Map[Int, Double] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_dir_attr : Map[String, String] = Map::new()
  let group_has_mixed_dir_attr : Map[String, Bool] = Map::new()
  let sameport_marked : Map[Int, Bool] = Map::new()
  let edge_by_id : Map[Int, @cgraph.Edge] = Map::new()
  let has_self_edge : Map[String, Bool] = Map::new()
  for edge in edges {
    edge_by_id[edge.id()] = edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      has_self_edge[tail] = true
    }
  }
  for edge in edges {
    let has_label = match edge_has_label_by_id.get(edge.id()) {
      Some(value) => value
      None => false
    }
    if has_label {
      continue
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    if orig_tail == orig_head {
      continue
    }
    let tail_rank = match ranks.get(orig_tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(orig_head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let key =
      @edge_ops.edge_parallel_key(
        orig_tail,
        orig_head,
        edge.tail_port(),
        edge.head_port(),
      )
    let dir_attr = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let mark = @edge_ops.edge_has_sameport_mark(edge)
    sameport_marked[edge.id()] = mark
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_dir_attr.get(key) {
      Some(first_dir) =>
        if first_dir != dir_attr {
          group_has_mixed_dir_attr[key] = true
        }
      None => {
        group_first_dir_attr[key] = dir_attr
        group_has_mixed_dir_attr[key] = false
      }
    }
  }
  let offsets : Map[Int, Double] = Map::new()
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    ids.sort_by((a, b) => {
      let a_mark = match sameport_marked.get(a) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      let b_mark = match sameport_marked.get(b) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      if a_mark != b_mark {
        b_mark - a_mark
      } else {
        a - b
      }
    })
    let mixed_dir = match group_has_mixed_dir_attr.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_dir {
      let mut left = 0
      let mut right = ids.length()
      while left + 1 < right {
        right = right - 1
        let tmp = ids[left]
        ids[left] = ids[right]
        ids[right] = tmp
        left = left + 1
      }
    }
    // Graphviz parity: for reverse-edge pairs, prefer the tail without a
    // self-loop first. This matches class2/dotsplines slot assignment on NaN.gv.
    if ids.length() == 2 {
      let edge0 = edge_by_id.get(ids[0])
      let edge1 = edge_by_id.get(ids[1])
      match (edge0, edge1) {
        (Some(a), Some(b)) => {
          let a_tail = a.tail().name()
          let a_head = a.head().name()
          let b_tail = b.tail().name()
          let b_head = b.head().name()
          if a_tail == b_head && a_head == b_tail {
            let a_tail_cluster = match cluster_keys.get(a_tail) {
              Some(value) => value
              None => ""
            }
            let a_head_cluster = match cluster_keys.get(a_head) {
              Some(value) => value
              None => ""
            }
            let intercluster =
              a_tail_cluster != a_head_cluster &&
              (a_tail_cluster != "" || a_head_cluster != "")
            let a_tail_has_self = match has_self_edge.get(a_tail) {
              Some(value) => value
              None => false
            }
            let b_tail_has_self = match has_self_edge.get(b_tail) {
              Some(value) => value
              None => false
            }
            // Graphviz parity: reverse-pair slot ordering applies to regular
            // intra-cluster pairs (rowe), but cluster-crossing pairs (clust2)
            // keep cluster-constrained ordering.
            if !intercluster && a_tail_has_self == b_tail_has_self {
              let a_reversed = match edge_reversed_by_id.get(ids[0]) {
                Some(value) => value
                None => false
              }
              let b_reversed = match edge_reversed_by_id.get(ids[1]) {
                Some(value) => value
                None => false
              }
              if !a_reversed && b_reversed {
                let tmp = ids[0]
                ids[0] = ids[1]
                ids[1] = tmp
              }
            }
            if a_tail_has_self && !b_tail_has_self {
              let tmp = ids[0]
              ids[0] = ids[1]
              ids[1] = tmp
            }
          }
        }
        _ => ()
      }
    }
    let count = ids.length()
    let dx = nodesep_pt * Double::from_int(count - 1) / 2.0
    for i in 0..<count {
      let offset = dx - Double::from_int(i) * nodesep_pt
      offsets[ids[i]] = offset
    }
  }
  offsets
}

///|
/// Graphviz parity: routing context aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn prepare_routing_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  cluster_bboxes : Map[String, @geom.Rect],
) -> RoutingContext {
  let order_index = build_order_index(ordered_groups)
  let path_order_index = build_order_index(x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(
      edges,
      vnode_info.edge_vnodes,
      edge_tail,
      edge_head,
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right space).
  let pathplan_sizes =
    apply_self_edge_right_space(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
    )
  // Graphviz parity: preserve original vnode widths for ND_mval usage.
  let pathplan_vnode_mval_sizes : Map[String, NodeSize] = Map::new()
  for name, size in vnode_info.vnode_sizes {
    pathplan_vnode_mval_sizes[name] = size
  }
  let path_cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    path_cluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let path_vnode_clusters =
    build_path_vnode_clusters(
      edges,
      vnode_info.edge_vnodes,
      vnode_positions,
      path_cluster_keys,
      cluster_bboxes,
    )
  let edge_reversed_by_id : Map[Int, Bool] = Map::new()
  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  for i in 0..<edges.length() {
    let edge = edges[i]
    let (oriented_tail, oriented_head) =
      edge_endpoints_at(
        edge,
        i,
        edge_tail,
        edge_head,
      )
    let reversed = edge_orientation_is_reversed(edge, oriented_tail, oriented_head)
    edge_reversed_by_id[edge.id()] = reversed
    edge_has_label_by_id[edge.id()] = edge_has_label(edge)
  }
  let parallel_offsets =
    build_edge_parallel_offsets(
      edges,
      edge_has_label_by_id,
      ranks,
      nodesep_pt,
      edge_reversed_by_id,
      path_cluster_keys,
    )
  {
    order_index,
    path_order_index,
    path_adjacency,
    pathplan_sizes,
    pathplan_vnode_mval_sizes,
    path_cluster_keys,
    path_vnode_clusters,
    parallel_offsets,
    cluster_bboxes,
  }
}
