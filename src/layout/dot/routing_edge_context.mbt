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
  base_cache : Map[Int, @routing.EdgeRouteBase]
  prepass : @routing.RoutePrepassState
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
}

///|
/// Graphviz parity: ordered-edge routing mutates only shared pass-level maps
/// while iterating in Graphviz-compatible route order.
priv struct OrderedEdgeRoutingState {
  recovered_slack_keys : Map[String, Bool]
  self_edge_routes : Map[Int, @routing.SelfEdgeRoute]
  edges_out_by_id : Map[Int, DotLayoutEdge]
}

///|
/// Graphviz parity: edge route bases are cached per edge id before routing.
/// Do not change behavior without updating fixtures/tests.
fn build_route_base_cache(
  edges : Array[@cgraph.Edge],
  build_base : (@cgraph.Edge) -> @routing.EdgeRouteBase,
) -> Map[Int, @routing.EdgeRouteBase] {
  let base_cache : Map[Int, @routing.EdgeRouteBase] = Map::new()
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
  base_cache : Map[Int, @routing.EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, @routing.SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[@routing.EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[@routing.SelfEdgeRoute],
) -> Unit {
  let edge_id = edge.id()
  if self_edge_routes.get(edge_id) is Some(_) {
    return ()
  }
  let key = self_edge_group_key(edge)
  match self_edge_groups.get(key) {
    Some(group_edges) => {
      let group_bases : Array[@routing.EdgeRouteBase] = []
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
  base_cache : Map[Int, @routing.EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, @routing.SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[@routing.EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[@routing.SelfEdgeRoute],
) -> @routing.SelfEdgeRoute? {
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
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
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
  spline_result : @routing.EdgeSplineResult
}

///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_edge(base : @routing.EdgeRouteBase) -> Array[String] {
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
  base : @routing.EdgeRouteBase,
  spline_result : @routing.EdgeSplineResult,
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
  let recover_key = @routing.recover_slack_key_for_edge(edge)
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
  base : @routing.EdgeRouteBase,
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
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let spline = @routing.finalize_edge_spline(base, layout_spline_result)
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
  base : @routing.EdgeRouteBase,
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
fn parallel_remap_edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
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
    if parallel_remap_edge_has_label(edge) {
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
  layout_spline_result : @routing.EdgeSplineResult
}

///|
/// Graphviz parity: bezier route rendering follows
/// build_bezier_points_spline -> edge_spline_result_for_bezier ->
/// rebuild_spline_for_render -> finalize_edge_spline.
/// Do not change behavior without updating fixtures/tests.
fn build_bezier_layout_spline_result(
  base : @routing.EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
) -> BezierLayoutSplineResult {
  let spline =
    @routing.build_bezier_points_spline(
      base,
      raw_bezier,
      base.tail_clip_enabled,
      base.head_clip_enabled,
      tail_swap,
      head_swap,
    )
  let spline_result =
    @routing.edge_spline_result_for_bezier(
      spline,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
    )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let final_spline = @routing.finalize_edge_spline(base, layout_spline_result)
  { final_spline, layout_spline_result }
}

///|
fn build_bezier_layout_edge(
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
  route : @routing.SelfEdgeRoute,
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
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
  shared_spline_result : @routing.EdgeSplineResult,
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
  base : @routing.EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : @routing.EdgeSplineResult,
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
  base0 : @routing.EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[@routing.SelfEdgeRoute] {
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
  let routes : Array[@routing.SelfEdgeRoute] = []
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
  base0 : @routing.EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[@routing.SelfEdgeRoute] {
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
  let routes : Array[@routing.SelfEdgeRoute] = []
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
  bases : Array[@routing.EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
) -> Array[@routing.SelfEdgeRoute] {
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
    let routes : Array[@routing.SelfEdgeRoute] = []
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
      let routes : Array[@routing.SelfEdgeRoute] = []
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
