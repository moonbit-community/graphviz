///|
/// Stage E routing-context precompute helpers.

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
priv struct RoutingPrecomputeData {
  port_pad_below : Double
  port_pad_above : Double
  head_port_metrics : @routing.HeadPortMetrics
  path_groups : Map[Int, Array[String]]
  routing_context : @routing.RoutingContext
}

///|
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
) -> RoutingPrecomputeData {
  let prep = input.prep
  // Graphviz parity: port padding and head-port metrics consume
  // routing-stage inputs while preserving compute order before spline routing.
  let port_padding =
    compute_port_padding(
      input.cluster_meta.has_clusters,
      prep.has_port_edges,
      prep.edges,
      input.positions_state.positions,
      input.label_ports_map,
    )
  let port_pad_below = port_padding.port_pad_below
  let port_pad_above = port_padding.port_pad_above
  let head_port_metrics =
    collect_head_port_metrics(
      prep.edges,
      input.positions_state.positions,
      input.sizes,
      input.label_ports_map,
      prep.record_orientation,
      input.enable_complex_tuning,
    )
  // Graphviz parity: routing path-context execution consumes routing-stage
  // fields while preserving path-group selection then context-assembly order.
  // Graphviz parity: path-groups selection prefers positioned x-groups,
  // then vnode-expanded order groups, then base order groups.
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    if input.positions_state.x_groups.length() > 0 {
      input.positions_state.x_groups
    } else if input.ordering.ordered_groups_with_vnodes.length() > 0 {
      input.ordering.ordered_groups_with_vnodes
    } else {
      input.ordering.ordered_groups
    }
  // Graphviz parity: routing context is assembled from routing-stage
  // inputs, final ordering, vnode/rank, and cluster bboxes.
  let routing_context =
    @routing.prepare_routing_context(
      prep.nodes,
      prep.edges,
      input.rank_data.edge_tail,
      input.rank_data.edge_head,
      input.sizes,
      input.rank_data.ranks,
      input.ordering.ordered_groups,
      path_groups,
      input.rank_heights.nodesep_pt,
      input.ordering.vnode_info.edge_vnodes,
      input.ordering.vnode_info.vnode_sizes,
      input.positions_state.vnode_positions,
      input.cluster_bboxes,
      @ordering.build_order_index,
      (nodes, edges, sizes) =>
        apply_self_edge_right_space(
          nodes,
          edges,
          sizes,
          prep.rankdir,
          prep.record_orientation,
        ),
      node_local_cluster_key,
    )
  {
    port_pad_below,
    port_pad_above,
    head_port_metrics,
    path_groups,
    routing_context,
  }
}
