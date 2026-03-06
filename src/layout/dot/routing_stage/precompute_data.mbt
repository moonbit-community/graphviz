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
/// Graphviz parity: routing edge solve precompute keeps metric and path-context
/// derivation in fixed order from typed edge/padding inputs before solve wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_routing_precompute_data(
  input : RoutingPrecomputeInput,
  deps : RoutingStageDeps,
) -> RoutingPrecomputeData {
  let prep = input.prep
  let port_padding =
    @routing.resolve_routing_port_padding(
      input.cluster_meta.has_clusters,
      prep.has_port_edges,
      () => {
        let padding =
          (deps.record_port_padding)(
            prep.edges,
            input.positions_state.positions,
            input.label_ports_map,
          )
        (padding.below, padding.above)
      },
    )
  let port_pad_below = port_padding.0
  let port_pad_above = port_padding.1
  let head_port_metrics =
    (deps.build_head_port_metrics)(
      prep.edges,
      input.enable_complex_tuning,
      input.positions_state.positions,
      input.sizes,
      prep.record_orientation,
      input.label_ports_map,
    )
  let pathplan_sizes =
    (deps.apply_self_edge_right_space)(
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
