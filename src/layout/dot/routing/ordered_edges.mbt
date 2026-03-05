///|
priv struct OrderedEdgeRoutingState {
  recovered_slack_keys : Map[String, Bool]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  edges_out_by_id : Map[Int, DotLayoutEdge]
}

///|
priv struct OrderedEdgeLayoutAttemptInput {
  edge : @cgraph.Edge
  edge_id : Int
  base : EdgeRouteBase
  input : OrderedRoutingInput
  state : OrderedEdgeRoutingState
  callbacks : RoutingCallbacks
}

///|
fn maybe_build_flat_adjacent_layout(
  input : OrderedEdgeLayoutAttemptInput,
) -> Bool {
  let edge_id = input.edge_id
  match input.input.flat_adjacent_simple_beziers.get(edge_id) {
    Some(bezier) => {
      let edge_layout =
        build_flat_adjacent_layout(
          input.base,
          bezier,
          input.callbacks.build_edge_layout_fn,
        )
      input.state.edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}

///|
fn maybe_build_self_edge_layout(
  input : OrderedEdgeLayoutAttemptInput,
) -> Bool {
  let edge = input.edge
  let edge_id = input.edge_id
  let route = self_edge_route_for_edge(
    {
      edge,
      self_edge_groups: input.input.self_edge_groups,
      base_cache: input.input.base_cache,
      nodesep_pt: input.input.nodesep_pt,
      rank_y: input.input.rank_y,
      self_edge_routes: input.state.self_edge_routes,
      self_edge_label_height_fn: input.callbacks.self_edge_label_height_fn,
      self_edge_label_width_fn: input.callbacks.self_edge_label_width_fn,
    },
  )
  match route {
    Some(route) => {
      let edge_layout =
        build_self_edge_layout(
          input.base,
          route,
          input.callbacks.build_edge_layout_fn,
        )
      input.state.edges_out_by_id[edge_id] = edge_layout
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
  callbacks : RoutingCallbacks,
) -> Unit {
  let edge_id = edge.id()
  if state.edges_out_by_id.get(edge_id) is Some(_) {
    return ()
  }
  let base = match input.base_cache.get(edge_id) {
    Some(value) => value
    None => return ()
  }
  let layout_attempt : OrderedEdgeLayoutAttemptInput = {
    edge,
    edge_id,
    base,
    input,
    state,
    callbacks,
  }
  if maybe_build_flat_adjacent_layout(
    layout_attempt,
  ) {
    return ()
  }
  if maybe_build_self_edge_layout(
    layout_attempt,
  ) {
    return ()
  }
  build_regular_layouts_for_edge(
    {
      edge_id,
      edge,
      base,
      input: input.regular_pass_input,
      path_left_bound: input.path_left_bound,
      path_right_bound: input.path_right_bound,
      recover_edge_id_by_key: input.recover_edge_id_for_routing,
      regular_parallel_groups: input.regular_parallel_groups,
      base_cache: input.base_cache,
      recovered_slack_keys: state.recovered_slack_keys,
      edges_out_by_id: state.edges_out_by_id,
      callbacks,
    },
  )
}

///|
/// Graphviz parity: ordered-edge routing loop keeps mutable self-edge and
/// recover-slack state shared across edges in pass order.
/// Do not change behavior without updating fixtures/tests.
pub fn route_ordered_edges(
  input : OrderedRoutingInput,
  edges_out_by_id : Map[Int, DotLayoutEdge],
  callbacks : RoutingCallbacks,
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
      callbacks,
    )
  }
}
