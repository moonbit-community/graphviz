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
  let spline_result = build_edge_spline(
    base,
    context.input.splines,
    context.input.ranks,
    context.input.sizes,
    context.input.positions,
    context.input.vnode_positions,
    context.input.vnode_info,
    context.input.rank_y,
    context.input.rank_ht1,
    context.input.rank_ht2,
    context.input.x_groups,
    context.input.nodesep_pt,
    context.prepass.path_left_bound,
    context.prepass.path_right_bound,
    context.input.ranksep_pt,
    context.input.label_edge_counts,
    context.input.head_port_metrics,
    context.input.routing_context,
    context.input.enable_complex_tuning,
  )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let spline = @routing.finalize_edge_spline(base, layout_spline_result)
  @routing.recover_pathplan_slack(
    edge,
    base,
    spline_result,
    context.input.ranks,
    context.input.vnode_info.vnode_ranks,
    context.input.rank_y,
    context.input.vnode_positions,
    context.input.vnode_info.vnode_sizes,
    context.input.routing_context.path_adjacency,
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
