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
/// Graphviz parity: pathplan recover_slack input keeps edge/spline snapshots,
/// rank maps, and mutable recover flags grouped for deterministic update order.
priv struct PathplanSlackRecoverInput {
  edge : @cgraph.Edge
  base : EdgeRouteBase
  spline_result : EdgeSplineResult
  input : RegularPassInput
  recover_edge_id_by_key : Map[String, Int]
  recovered_slack_keys : Map[String, Bool]
  callbacks : RoutingCallbacks
}

///|
/// Graphviz parity: pathplan recover_slack runs with limitBoxes before vnode updates.
/// Do not change behavior without updating fixtures/tests.
fn recover_pathplan_slack(
  recover_input : PathplanSlackRecoverInput,
) -> Unit {
  if !recover_input.spline_result.using_pathplan {
    return ()
  }
  let recover_key = recover_slack_key_for_edge(recover_input.edge)
  match recover_input.recover_edge_id_by_key.get(recover_key) {
    Some(recover_edge_id) =>
      if recover_edge_id != recover_input.edge.id() {
        return ()
      }
    None => ()
  }
  if recover_input.recovered_slack_keys.get(recover_key) is Some(_) {
    return ()
  }
  if recover_input.spline_result.pathplan_segments.length() > 0 {
    let mut did_recover = false
    // Graphviz parity: straight_path recovers slack per routed segment.
    for segment in recover_input.spline_result.pathplan_segments {
      if segment.vnodes.length() == 0 || segment.boxes.length() == 0 {
        continue
      }
      let ordered_vnodes =
        ordered_vnodes_for_rank_direction(
          segment.vnodes,
          recover_input.base.tail_rank,
          recover_input.base.head_rank,
        )
      (recover_input.callbacks.recover_slack_vnodes_fn)(
        recover_input.edge,
        ordered_vnodes,
        segment.boxes,
        recover_input.input.ranks,
        recover_input.input.vnode_info.vnode_ranks,
        recover_input.input.rank_y,
        recover_input.input.vnode_positions,
        recover_input.input.vnode_info.vnode_sizes,
        recover_input.input.routing_context.path_adjacency,
      )
      did_recover = true
    }
    if did_recover {
      recover_input.recovered_slack_keys[recover_key] = true
    }
    return ()
  }
  if recover_input.spline_result.pathplan_boxes.length() == 0 ||
    recover_input.spline_result.raw_bezier.length() < 4 {
    return ()
  }
  let limited_boxes =
    @routesplines.limit_boxes_for_spline(
      recover_input.spline_result.pathplan_boxes,
      recover_input.spline_result.raw_bezier,
      fallback_polyline=recover_input.spline_result.pathplan_points,
    )
  let ordered_vnodes = ordered_vnodes_for_edge(recover_input.base)
  (recover_input.callbacks.recover_slack_vnodes_fn)(
    recover_input.edge,
    ordered_vnodes,
    limited_boxes,
    recover_input.input.ranks,
    recover_input.input.vnode_info.vnode_ranks,
    recover_input.input.rank_y,
    recover_input.input.vnode_positions,
    recover_input.input.vnode_info.vnode_sizes,
    recover_input.input.routing_context.path_adjacency,
  )
  recover_input.recovered_slack_keys[recover_key] = true
}

///|
/// Graphviz parity: regular-spline layout input keeps solve bounds, recover
/// state, and callbacks grouped for one build/finalize/recover sequence.
priv struct RegularSplineLayoutBuildInput {
  edge : @cgraph.Edge
  base : EdgeRouteBase
  input : RegularPassInput
  path_left_bound : Double
  path_right_bound : Double
  recover_edge_id_by_key : Map[String, Int]
  recovered_slack_keys : Map[String, Bool]
  callbacks : RoutingCallbacks
}

///|
/// Graphviz parity: regular-edge routing keeps build/finalize/recover_slack flow.
/// Do not change behavior without updating fixtures/tests.
fn build_regular_spline_layout(
  layout_input : RegularSplineLayoutBuildInput,
) -> RegularSplineLayoutResult {
  let spline_result = build_edge_spline(
    layout_input.base,
    layout_input.input.spline_mode,
    layout_input.input.ranks,
    layout_input.input.sizes,
    layout_input.input.positions,
    layout_input.input.vnode_positions,
    layout_input.input.vnode_info,
    layout_input.input.rank_y,
    layout_input.input.rank_ht1,
    layout_input.input.rank_ht2,
    layout_input.input.x_groups,
    layout_input.input.nodesep_pt,
    layout_input.path_left_bound,
    layout_input.path_right_bound,
    layout_input.input.ranksep_pt,
    layout_input.input.label_edge_counts,
    layout_input.input.head_port_metrics,
    layout_input.input.routing_context,
    layout_input.input.enable_complex_tuning,
  )
  let layout_spline_result =
    rebuild_spline_for_render(layout_input.base, spline_result)
  let spline =
    finalize_edge_spline(layout_input.base, layout_spline_result)
  recover_pathplan_slack(
    {
      edge: layout_input.edge,
      base: layout_input.base,
      spline_result,
      input: layout_input.input,
      recover_edge_id_by_key: layout_input.recover_edge_id_by_key,
      recovered_slack_keys: layout_input.recovered_slack_keys,
      callbacks: layout_input.callbacks,
    },
  )
  let layout =
    (layout_input.callbacks.build_edge_layout_fn)(
      layout_input.base,
      spline,
      layout_spline_result,
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
/// Graphviz parity: regular parallel-reuse input keeps base cache, sibling
/// groups, and output map grouped for one deterministic reuse expansion.
priv struct RegularParallelReuseLayoutsInput {
  edge : @cgraph.Edge
  regular_layout : RegularSplineLayoutResult
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  base_cache : Map[Int, EdgeRouteBase]
  edges_out_by_id : Map[Int, DotLayoutEdge]
  callbacks : RoutingCallbacks
}

///|
/// Graphviz parity: regular-edge sibling reuse expands only for selected
/// parallel vnode classes.
/// Do not change behavior without updating fixtures/tests.
fn apply_regular_parallel_reuse_layouts(
  reuse_input : RegularParallelReuseLayoutsInput,
) -> Unit {
  let sibling_edges =
    collect_parallel_reuse_siblings(
      reuse_input.edge,
      reuse_input.regular_layout.spline_result.raw_bezier,
      reuse_input.regular_parallel_groups,
    )
  if sibling_edges.length() == 0 {
    return ()
  }
  for group_edge in sibling_edges {
    let group_edge_id = group_edge.id()
    let group_base = match reuse_input.base_cache.get(group_edge_id) {
      Some(value) => value
      None => continue
    }
    let group_layout =
      build_regular_bezier_layout(
        group_base,
        reuse_input.regular_layout.spline_result,
        reuse_input.callbacks.build_edge_layout_fn,
      )
    reuse_input.edges_out_by_id[group_edge_id] = group_layout
  }
}

///|
/// Graphviz parity: regular-layout input keeps edge solve state and mutable
/// output/recover maps grouped for one regular pass boundary.
pub(all) struct RegularLayoutsForEdgeInput {
  edge_id : Int
  edge : @cgraph.Edge
  base : EdgeRouteBase
  input : RegularPassInput
  path_left_bound : Double
  path_right_bound : Double
  recover_edge_id_by_key : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  base_cache : Map[Int, EdgeRouteBase]
  recovered_slack_keys : Map[String, Bool]
  edges_out_by_id : Map[Int, DotLayoutEdge]
  callbacks : RoutingCallbacks
}

///|
/// Graphviz parity: regular-edge routing keeps edge solve + parallel-reuse
/// expansion together after flat/self branches are skipped.
/// Do not change behavior without updating fixtures/tests.
pub fn build_regular_layouts_for_edge(
  regular_input : RegularLayoutsForEdgeInput,
) -> Unit {
  let regular_layout = build_regular_spline_layout(
    {
      edge: regular_input.edge,
      base: regular_input.base,
      input: regular_input.input,
      path_left_bound: regular_input.path_left_bound,
      path_right_bound: regular_input.path_right_bound,
      recover_edge_id_by_key: regular_input.recover_edge_id_by_key,
      recovered_slack_keys: regular_input.recovered_slack_keys,
      callbacks: regular_input.callbacks,
    },
  )
  regular_input.edges_out_by_id[regular_input.edge_id] = regular_layout.edge_layout
  apply_regular_parallel_reuse_layouts(
    {
      edge: regular_input.edge,
      regular_layout,
      regular_parallel_groups: regular_input.regular_parallel_groups,
      base_cache: regular_input.base_cache,
      edges_out_by_id: regular_input.edges_out_by_id,
      callbacks: regular_input.callbacks,
    },
  )
}
