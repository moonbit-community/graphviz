///|
fn build_route_base_cache(
  input : RouteEdgesPipelineInput,
  route_base_deps : RouteBaseDeps,
  sameport_overrides : SameportOverrides,
) -> Map[Int, EdgeRouteBase] {
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in input.edges {
    let edge_id = edge.id()
    if base_cache.get(edge_id) is None {
      base_cache[edge_id] =
        build_edge_route_base(
          input,
          edge,
          route_base_deps,
          sameport_overrides,
        )
    }
  }
  base_cache
}

///|
fn build_route_edges_input(
  input : RouteEdgesPipelineInput,
  base_cache : Map[Int, EdgeRouteBase],
) -> RouteEdgesInput {
  {
    edges: input.edges,
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
    flat_label_edge_vnodes: input.flat_label_edge_vnodes,
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
    use_spline_prepass: input.use_spline_prepass,
    spline_mode: input.spline_mode,
    base_cache,
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn route_edges_pipeline(
  input : RouteEdgesPipelineInput,
  route_base_deps : RouteBaseDeps,
  recover_slack_vnodes_fn : RecoverSlackVnodesFn,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
  self_edge_label_height_fn : SelfEdgeLabelMetricFn,
  self_edge_label_width_fn : SelfEdgeLabelMetricFn,
  edge_port_label_pos_fn : EdgePortLabelPosFn,
) -> Array[DotLayoutEdge] {
  let sameport_overrides =
    collect_sameport_overrides(
      input.edges,
      input.positions,
      input.sizes,
      route_base_deps.node_size_for_missing,
      input.layout_rankdir,
      input.ranksep_pt,
    )
  let base_cache =
    build_route_base_cache(
      input,
      route_base_deps,
      sameport_overrides,
    )
  let route_input = build_route_edges_input(input, base_cache)
  route_edges(
    route_input,
    recover_slack_vnodes_fn,
    build_edge_layout_fn,
    self_edge_label_height_fn,
    self_edge_label_width_fn,
    edge_port_label_pos_fn,
  )
}
