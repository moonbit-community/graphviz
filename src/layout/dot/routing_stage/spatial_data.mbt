priv struct RoutingSpatialData {
  nodes_out : Array[DotLayoutNode]
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing spatial payload keeps stage context grouped so
/// node/port and cluster-bbox precompute wiring stays explicit and stable.
priv struct RoutingSpatialInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
  ranks : Map[String, Int]
  positions_state : PositionResult
}

///|
/// Graphviz parity: routing spatial precompute consumes typed routing-stage
/// inputs and keeps node/port + cluster-bbox computation order unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_spatial_data(
  input : RoutingSpatialInput,
  deps : RoutingStageDeps,
) -> RoutingSpatialData {
  let prep = input.prep
  let positions_state = input.positions_state
  let nodes_out =
    (deps.build_layout_nodes)(
      prep.nodes,
      positions_state.positions,
      prep.output_sizes,
      prep.record_orientation,
    )
  let port_layout_maps =
    (deps.build_port_layout_maps)(
      nodes_out,
      prep.output_sizes,
      prep.record_orientation,
      prep.rankdir,
      prep.has_port_edges,
    )
  let cluster_bboxes =
    (deps.compute_cluster_route_bboxes)(
      input.graph,
      nodes_out,
      positions_state.cluster_ln_x,
      positions_state.cluster_rn_x,
      positions_state.cluster_bbox_heights,
      prep.rankdir,
      input.ranks,
      positions_state.rank_y,
      positions_state.rank_ht1,
      positions_state.rank_ht2,
    )
  {
    nodes_out,
    label_ports_map: port_layout_maps.label_ports_map,
    label_ports_raw: port_layout_maps.label_ports_raw,
    cluster_bboxes,
  }
}
