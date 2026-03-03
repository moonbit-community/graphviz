priv struct RegularSplineLayoutResult {
  edge_layout : DotLayoutEdge
  spline_result : EdgeSplineResult
}

///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_rank_direction(
  vnodes : Array[String],
  tail_rank : Int,
  head_rank : Int,
) -> Array[String] {
  if tail_rank <= head_rank {
    vnodes.copy()
  } else {
    let reversed : Array[String] = []
    let mut idx = vnodes.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(vnodes[idx])
    }
    reversed
  }
}

///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_edge(base : EdgeRouteBase) -> Array[String] {
  ordered_vnodes_for_rank_direction(base.vnodes, base.tail_rank, base.head_rank)
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
        ordered_vnodes_for_rank_direction(
          segment.vnodes,
          base.tail_rank,
          base.head_rank,
        )
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
  let spline_mode =
    match input.splines {
      SplinesMode::None | SplinesMode::Polyline => 0
      SplinesMode::Ortho => 1
      _ => 2
    }
  let spline_result = @routing.build_edge_spline(
    base,
    spline_mode,
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
  let layout_spline_result =
    @routing.rebuild_spline_for_render(base, spline_result)
  let spline =
    @routing.finalize_edge_spline(base, layout_spline_result)
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
      @routing.build_regular_bezier_layout(
        group_base,
        regular_layout.spline_result,
        (route_base, spline, spline_result) =>
          build_edge_layout(
            route_base,
            spline,
            spline_result,
            context,
          ),
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
