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
    @routing.build_route_base_cache(
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
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
fn remap_parallel_edge_layouts(
  input : EdgeRoutingPassInput,
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let assignments =
    @routing.build_parallel_remap_assignments(
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
    @routing.collect_input_order_edge_ids(
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
