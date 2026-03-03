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
  prepass : @routing.RoutePrepassState
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
  {
    input,
    base_cache,
    prepass,
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
  let route = @routing.self_edge_route_for_edge(
    edge,
    context.prepass.self_edge_groups,
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
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let spline = @routing.finalize_edge_spline(base, layout_spline_result)
  @routing.recover_pathplan_slack(
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
    @routing.collect_parallel_reuse_siblings(
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
