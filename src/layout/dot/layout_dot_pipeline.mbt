///|
priv struct DotRankStage {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStage {
  let rank_data = compute_rank_data(
    graph,
    prep.nodes,
    prep.edges,
    prep.has_edge_labels,
  )
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.ranks,
  )
  let rank_heights = compute_rank_heights(
    graph,
    prep.edges,
    rank_data.ranks,
    rank_data.groups,
    rank_data.rank_keys,
    rank_data.all_ranks,
    prep.sizes,
    rank_data.self_edge_labels,
    prep.rankdir,
    prep.nodesep_in,
    prep.ranksep_in,
    prep.has_edge_labels,
  )
  let cluster_meta =
    compute_cluster_metadata(
      graph,
      prep.nodes,
      prep.edges,
      rank_data.groups,
      rank_data.ranks,
      prep.node_order,
      rank_data.edge_tail,
      rank_data.edge_head,
      prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL,
    )
  let ordering = compute_ordering_and_vnodes(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.edge_reversed,
    rank_data.edge_out_order,
    rank_data.ranks,
    rank_data.groups,
    rank_data.rank_keys,
    prep.node_order,
    prep.order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    prep.rankdir,
    cluster_meta,
    prep.port_order_positions,
    prep.port_order_contrib,
  )
  dot_trace("layout_dot: rank order computed")
  { rank_data, rank_heights, cluster_meta, ordering }
}

///|
/// Graphviz parity: dot position stage mirrors refs/graphviz/lib/dotgen/position.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_position_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
) -> PositionResult {
  compute_positions(
    graph,
    prep,
    rank_stage.rank_data,
    rank_stage.rank_heights,
    rank_stage.cluster_meta,
    rank_stage.ordering,
  )
}

///|
priv struct DotRoutingStage {
  nodes_out : Array[DotLayoutNode]
  edges_out : Array[DotLayoutEdge]
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: dot splines stage mirrors refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_routing_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_stage : DotRankStage,
  positions_state : PositionResult,
) -> DotRoutingStage {
  let nodes_out =
    build_layout_nodes(
      prep.nodes,
      positions_state.positions,
      prep.output_sizes,
      prep.record_orientation,
    )
  let port_maps =
    build_port_layout_maps(
      nodes_out,
      prep.output_sizes,
      prep.record_orientation,
      prep.rankdir,
      prep.has_port_edges,
    )
  let label_ports_map = port_maps.label_ports_map
  let label_ports_raw = port_maps.label_ports_raw
  let cluster_bboxes =
    compute_cluster_bboxes_for_routing(
      graph,
      nodes_out,
      positions_state.cluster_ln_x,
      positions_state.cluster_rn_x,
    )
  let label_edge_counts = build_label_edge_counts(prep.edges)
  let enable_complex_tuning = complex_tuning_enabled()
  let (port_pad_below, port_pad_above) =
    compute_port_padding(
      rank_stage.cluster_meta.has_clusters,
      prep.has_port_edges,
      prep.edges,
      positions_state.positions,
      label_ports_map,
    )
  let head_port_metrics =
    collect_head_port_metrics(
      prep.edges,
      positions_state.positions,
      prep.sizes,
      label_ports_map,
      prep.record_orientation,
      enable_complex_tuning,
    )
  // Graphviz parity: pathplan uses final x-order (after positioning) with vnodes.
  let path_groups =
    if positions_state.x_groups.length() > 0 {
      positions_state.x_groups
    } else if rank_stage.ordering.ordered_groups_with_vnodes.length() > 0 {
      rank_stage.ordering.ordered_groups_with_vnodes
    } else {
      rank_stage.ordering.ordered_groups
    }
  let routing_context =
    prepare_routing_context(
      prep.nodes,
      prep.edges,
      rank_stage.rank_data.edge_tail,
      rank_stage.rank_data.edge_head,
      prep.sizes,
      prep.rankdir,
      prep.record_orientation,
      rank_stage.rank_data.ranks,
      rank_stage.ordering.ordered_groups,
      path_groups,
      rank_stage.rank_heights.nodesep_pt,
      rank_stage.ordering.vnode_info,
      positions_state.vnode_positions,
      cluster_bboxes,
    )
  let layout_rankdir = RankDir::TB
  let edges_out =
    route_edges(
      graph,
      prep.edges,
      rank_stage.rank_data.ranks,
      prep.sizes,
      prep.record_orientation,
      prep.rankdir,
      layout_rankdir,
      prep.splines,
      positions_state.positions,
      positions_state.vnode_positions,
      rank_stage.ordering.vnode_info,
      positions_state.rank_y,
      positions_state.rank_ht1,
      positions_state.rank_ht2,
      path_groups,
      rank_stage.rank_heights.nodesep_pt,
      rank_stage.rank_heights.ranksep_pt,
      rank_stage.cluster_meta.has_clusters,
      label_ports_map,
      label_ports_raw,
      label_edge_counts,
      head_port_metrics,
      positions_state.flat_label_edge_vnodes,
      routing_context,
      enable_complex_tuning,
    )
  dot_trace("layout_dot: edges routed")
  { nodes_out, edges_out, port_pad_below, port_pad_above }
}
