///|
/// Stage E routing-context precompute and edge metric helpers.

///|
/// Graphviz parity: routing precompute payload keeps context snapshots grouped
/// so port metrics and path-context wiring stay explicit and stable.
priv struct RoutingPrecomputeInput {
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  positions_state : PositionResult
  label_ports_map : Map[String, Map[String, RecordPort]]
  cluster_bboxes : Map[String, @geom.Rect]
  sizes : Map[String, NodeSize]
  enable_complex_tuning : Bool
}

///|
type RoutingPrecomputeData = @routing.RoutingPrecomputePipelineOutput

///|
/// Graphviz parity: complex head-port tuning keys match dotsplines behavior:
/// explicit port key when present, otherwise record-shape node key.
fn routing_head_metric_key(edge : @cgraph.Edge) -> String {
  let head_name = edge.head().name()
  let head_port = @dot_shared.port_key(edge.head_port())
  if head_port == "" {
    if is_record_shape(edge.head()) { head_name } else { "" }
  } else {
    "\{head_name}:\{head_port}"
  }
}

///|
/// Graphviz parity: complex tuning distance uses endpoint port centers in
/// current routing coordinates.
fn routing_head_metric_distance(
  edge : @cgraph.Edge,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  record_orientation : RecordOrientation,
) -> Double {
  let tail_name = edge.tail().name()
  let head_name = edge.head().name()
  let tail_pos =
    positions.get(tail_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let head_pos =
    positions.get(head_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let tail_size = sizes.get(tail_name).unwrap_or(node_size(edge.tail(), record_orientation))
  let head_size = sizes.get(head_name).unwrap_or(node_size(edge.head(), record_orientation))
  let tail_geometry =
    port_geometry(
      tail_name,
      edge.tail_port(),
      label_ports_map,
      tail_pos,
      tail_size,
    )
  let head_geometry =
    port_geometry(
      head_name,
      edge.head_port(),
      label_ports_map,
      head_pos,
      head_size,
    )
  let dx = head_geometry.center.x - tail_geometry.center.x
  let dy = head_geometry.center.y - tail_geometry.center.y
  Double::sqrt(dx * dx + dy * dy)
}

///|
/// Graphviz parity: head-port metric aggregation mirrors dotsplines
/// count/min/max accumulation for complex tuning.
fn build_routing_head_port_metrics(
  prep : LayoutPrep,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  enable_complex_tuning : Bool,
) -> @routing.HeadPortMetrics {
  @routing.build_head_port_metrics(
    prep.edges,
    enable_complex_tuning,
    (edge) => {
      let key = routing_head_metric_key(edge)
      if key == "" {
        None
      } else {
        let dist =
          routing_head_metric_distance(
            edge,
            positions,
            sizes,
            label_ports_map,
            prep.record_orientation,
          )
        Some((key, dist))
      }
    },
  )
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  let (port_pad_below, port_pad_above) =
    @routing.resolve_routing_port_padding(
      input.cluster_meta.has_clusters,
      prep.has_port_edges,
      () => {
        let padding =
          record_port_padding_y(
            prep.edges,
            input.positions_state.positions,
            input.label_ports_map,
          )
        (padding.below, padding.above)
      },
    )
  let head_port_metrics =
    build_routing_head_port_metrics(
      prep,
      input.positions_state.positions,
      input.sizes,
      input.label_ports_map,
      input.enable_complex_tuning,
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right space).
  let pathplan_sizes =
    apply_self_edge_right_space(
      prep.nodes,
      prep.edges,
      input.sizes,
      prep.rankdir,
      prep.record_orientation,
    )
  @routing.build_routing_precompute_pipeline(
    {
      edges: prep.edges,
      x_groups: input.positions_state.x_groups,
      ordered_groups_with_vnodes: input.ordering.ordered_groups_with_vnodes,
      ordered_groups: input.ordering.ordered_groups,
      port_pad_below,
      port_pad_above,
      head_port_metrics,
      edge_tail: input.rank_data.edge_tail,
      edge_head: input.rank_data.edge_head,
      ranks: input.rank_data.ranks,
      nodesep_pt: input.rank_heights.nodesep_pt,
      edge_vnodes: input.ordering.vnode_info.edge_vnodes,
      pathplan_sizes,
      path_cluster_keys: input.cluster_meta.intercluster_keys,
      vnode_sizes: input.ordering.vnode_info.vnode_sizes,
      vnode_positions: input.positions_state.vnode_positions,
      cluster_bboxes: input.cluster_bboxes,
    },
  )
}
