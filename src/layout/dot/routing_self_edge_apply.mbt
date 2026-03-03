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
  let route = @routing.self_edge_route_for_edge(
    edge,
    context.self_edge_groups,
    context.base_cache,
    context.nodesep_pt,
    context.rank_y,
    state.self_edge_routes,
    context.build_base_for_edge,
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
