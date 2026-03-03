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
    context.splines,
    context.ranks,
    context.sizes,
    context.positions,
    context.vnode_positions,
    context.vnode_info,
    context.rank_y,
    context.rank_ht1,
    context.rank_ht2,
    context.x_groups,
    context.nodesep_pt,
    context.prepass.path_left_bound,
    context.prepass.path_right_bound,
    context.ranksep_pt,
    context.label_edge_counts,
    context.head_port_metrics,
    context.routing_context,
    context.enable_complex_tuning,
  )
  let layout_spline_result = @routing.rebuild_spline_for_render(base, spline_result)
  let spline = @routing.finalize_edge_spline(base, layout_spline_result)
  @routing.recover_pathplan_slack(
    edge,
    base,
    spline_result,
    context.ranks,
    context.vnode_info.vnode_ranks,
    context.rank_y,
    context.vnode_positions,
    context.vnode_info.vnode_sizes,
    context.path_adjacency,
    context.prepass.recover_edge_id_for_routing,
    recovered_slack_keys,
    recover_slack_vnodes,
  )
  let layout =
    build_edge_layout(
      base,
      spline,
      layout_spline_result,
      context.ranks,
      context.rank_y,
      context.vnode_info,
      context.vnode_positions,
      context.nodesep_pt,
      context.has_clusters,
      context.flat_label_edge_vnodes,
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
