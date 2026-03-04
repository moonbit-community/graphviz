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
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        has_edge_labels: prep.has_edge_labels,
      },
    )
  // Graphviz parity: rank-height stage consumes computed ranks/groups
  // and spacing inputs with unchanged Graphviz argument wiring.
  let rank_heights =
    compute_rank_heights(
      {
        graph,
        edges: prep.edges,
        ranks: rank_data.ranks,
        groups: rank_data.groups,
        rank_keys: rank_data.rank_keys,
        all_ranks: rank_data.all_ranks,
        sizes: prep.sizes,
        self_edge_labels: rank_data.self_edge_labels,
        rankdir: prep.rankdir,
        nodesep_in: prep.nodesep_in,
        ranksep_in: prep.ranksep_in,
        has_edge_labels: prep.has_edge_labels,
      },
    )
  // Graphviz parity: cluster metadata in rank/order stage uses
  // the same rank-group and edge endpoint wiring as Graphviz ordering setup.
  let cluster_meta =
    compute_cluster_metadata(
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        groups: rank_data.groups,
        ranks: rank_data.ranks,
        node_order: prep.node_order,
        edge_tail: rank_data.edge_tail,
        edge_head: rank_data.edge_head,
        graphviz_flip: prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL,
      },
    )
  // Graphviz parity: ordering/vnode stage consumes rank data, rank heights,
  // and cluster metadata with unchanged Graphviz call wiring.
  let ordering =
    compute_ordering_and_vnodes(
      {
        graph,
        nodes: prep.nodes,
        edges: prep.edges,
        edge_tail: rank_data.edge_tail,
        edge_head: rank_data.edge_head,
        edge_reversed: rank_data.edge_reversed,
        edge_out_order: rank_data.edge_out_order,
        ranks: rank_data.ranks,
        groups: rank_data.groups,
        rank_keys: rank_data.rank_keys,
        node_order: prep.node_order,
        order_sizes: prep.order_sizes,
        nodesep_pt: rank_heights.nodesep_pt,
        has_edge_labels: prep.has_edge_labels,
        rankdir: prep.rankdir,
        cluster_meta,
        port_order_positions: prep.port_order_positions,
        port_order_contrib: prep.port_order_contrib,
      },
    )
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged.
  { rank_data, rank_heights, cluster_meta, ordering }
}
