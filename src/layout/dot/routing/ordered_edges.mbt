///|
priv struct OrderedEdgeRoutingState {
  recovered_slack_keys : Map[String, Bool]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  edges_out_by_id : Map[Int, DotLayoutEdge]
}

///|
fn maybe_build_flat_adjacent_layout(
  edge_id : Int,
  base : EdgeRouteBase,
  input : OrderedRoutingInput,
  state : OrderedEdgeRoutingState,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
) -> Bool {
  match input.flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        build_flat_adjacent_layout(
          base,
          bezier,
          build_edge_layout_fn,
        )
      state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
fn maybe_build_self_edge_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  input : OrderedRoutingInput,
  state : OrderedEdgeRoutingState,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
  self_edge_label_height_fn : SelfEdgeLabelMetricFn,
  self_edge_label_width_fn : SelfEdgeLabelMetricFn,
) -> Bool {
  let edge_id = edge.id()
  let route = self_edge_route_for_edge(
    edge,
    input.self_edge_groups,
    input.base_cache,
    input.nodesep_pt,
    input.rank_y,
    state.self_edge_routes,
    self_edge_label_height_fn,
    self_edge_label_width_fn,
  )
  match route {
    Some(route) => {
      let edge_layout =
        build_self_edge_layout(
          base,
          route,
          build_edge_layout_fn,
        )
      state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
fn route_ordered_edge(
  edge : @cgraph.Edge,
  input : OrderedRoutingInput,
  state : OrderedEdgeRoutingState,
  recover_slack_vnodes_fn : RecoverSlackVnodesFn,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
  self_edge_label_height_fn : SelfEdgeLabelMetricFn,
  self_edge_label_width_fn : SelfEdgeLabelMetricFn,
) -> Unit {
  let edge_id = edge.id()
  if state.edges_out_by_id.get(edge_id) is Some(_) {
    return ()
  }
  let base = match input.base_cache.get(edge_id) {
    Some(value) => value
    None => return ()
  }
  if maybe_build_flat_adjacent_layout(
    edge_id,
    base,
    input,
    state,
    build_edge_layout_fn,
  ) {
    return ()
  }
  if maybe_build_self_edge_layout(
    edge,
    base,
    input,
    state,
    build_edge_layout_fn,
    self_edge_label_height_fn,
    self_edge_label_width_fn,
  ) {
    return ()
  }
  build_regular_layouts_for_edge(
    edge_id,
    edge,
    base,
    input.regular_pass_input,
    input.path_left_bound,
    input.path_right_bound,
    input.recover_edge_id_for_routing,
    input.regular_parallel_groups,
    input.base_cache,
    state.recovered_slack_keys,
    state.edges_out_by_id,
    recover_slack_vnodes_fn,
    build_edge_layout_fn,
  )
}

///|
/// Graphviz parity: ordered-edge routing loop keeps mutable self-edge and
/// recover-slack state shared across edges in pass order.
/// Do not change behavior without updating fixtures/tests.
pub fn route_ordered_edges(
  input : OrderedRoutingInput,
  edges_out_by_id : Map[Int, DotLayoutEdge],
  recover_slack_vnodes_fn : RecoverSlackVnodesFn,
  build_edge_layout_fn : EdgeLayoutBuilderFn,
  self_edge_label_height_fn : SelfEdgeLabelMetricFn,
  self_edge_label_width_fn : SelfEdgeLabelMetricFn,
) -> Unit {
  let state : OrderedEdgeRoutingState = {
    recovered_slack_keys: Map::new(),
    self_edge_routes: Map::new(),
    edges_out_by_id,
  }
  for edge in input.ordered_edges {
    route_ordered_edge(
      edge,
      input,
      state,
      recover_slack_vnodes_fn,
      build_edge_layout_fn,
      self_edge_label_height_fn,
      self_edge_label_width_fn,
    )
  }
}
