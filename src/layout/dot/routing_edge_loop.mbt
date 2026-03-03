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
  match context.prepass.flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        build_flat_adjacent_layout(
          base,
          bezier,
          context,
        )
      state.edges_out_by_id[edge_id] = edge_layout
      return ()
    }
    None => ()
  }
  if maybe_build_self_edge_layout(
    edge,
    base,
    context,
    state,
  ) {
    return ()
  }
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
