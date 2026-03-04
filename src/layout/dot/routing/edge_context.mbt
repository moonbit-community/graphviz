///|
fn build_regular_pass_input(
  input : RouteEdgesInput,
) -> RegularPassInput {
  {
    spline_mode: input.spline_mode,
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
    routing_context: input.routing_context,
    enable_complex_tuning: input.enable_complex_tuning,
  }
}

///|
fn build_ordered_routing_input(
  input : RouteEdgesInput,
) -> OrderedRoutingInput {
  let prepass =
    build_route_prepass_state(
      {
        edges: input.edges,
        base_cache: input.base_cache,
        build_flat_adjacent_beziers: input.use_spline_prepass,
        ranks: input.ranks,
        order_index: input.routing_context.order_index,
        path_order_index: input.routing_context.path_order_index,
        positions: input.positions,
        vnode_positions: input.vnode_positions,
        sizes: input.sizes,
        vnode_sizes: input.vnode_info.vnode_sizes,
        x_groups: input.x_groups,
      },
    )
  let self_edge_groups = collect_self_edge_groups(input.edges)
  {
    ordered_edges: prepass.ordered_edges,
    flat_adjacent_simple_beziers: prepass.flat_adjacent_simple_beziers,
    base_cache: input.base_cache,
    self_edge_groups,
    regular_pass_input: build_regular_pass_input(input),
    path_left_bound: prepass.path_left_bound,
    path_right_bound: prepass.path_right_bound,
    recover_edge_id_for_routing: prepass.recover_edge_id_for_routing,
    regular_parallel_groups: prepass.regular_parallel_groups,
    rank_y: input.rank_y,
    nodesep_pt: input.nodesep_pt,
  }
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn route_edges(
  input : RouteEdgesInput,
  callbacks : RoutingCallbacks,
) -> Array[DotLayoutEdge] {
  let ordered_routing_input = build_ordered_routing_input(input)
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  route_ordered_edges(
    ordered_routing_input,
    edges_out_by_id,
    callbacks,
  )
  finalize_routed_edges(
    input.edges,
    input.ranks,
    edges_out_by_id,
    callbacks.edge_port_label_pos_fn,
  )
}
