///|
/// Stage B rank-stage orchestrator and output payload.

///|
priv struct DotRankStageOutput {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
) -> DotRankStageOutput {
  // Graphviz parity: rank-data creation remains first before downstream stage assembly.
  let rank_data =
    compute_rank_data(
      graph,
      prep.nodes,
      prep.edges,
      prep.has_edge_labels,
    )
  // Graphviz parity: rank-height stage consumes computed ranks/groups
  // and spacing inputs with unchanged Graphviz argument wiring.
  let rank_heights =
    compute_rank_heights(
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
  // Graphviz parity: cluster metadata in rank/order stage uses
  // the same rank-group and edge endpoint wiring as Graphviz ordering setup.
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
  // Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
  // and cluster metadata with unchanged Graphviz call wiring.
  let ordering =
    compute_ordering_and_vnodes(
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
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged.
  { rank_data, rank_heights, cluster_meta, ordering }
}
