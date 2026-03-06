///|
/// Stage B rank stage orchestration with rank-assignment kernels delegated to
/// the rank_assignment subpackage.

///|
type RankData = @rank_assignment.RankData

///|
type RankHeights = @rank_assignment.RankHeights
type OrderingStageDeps = @ordering_stage.OrderingStageDeps
type OrderingStageOutput = @ordering_stage.OrderingStageOutput
type OrderingResult = @ordering.OrderingResult

///|
/// Graphviz parity: cluster metadata payload keeps rank and cluster snapshots
/// grouped so Stage B clustered-ordering wiring remains explicit and stable.
type ClusterMetadata = @ordering.DotClusterMetadata

///|
/// Graphviz parity: rank stage payload keeps Stage A-prepared inputs grouped
/// so Stage B wiring remains explicit and stable.
priv struct DotRankStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
}

///|
priv struct DotRankStageOutput {
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: stage-B rank height computation uses the same edge label
/// width/height inputs as node geometry to preserve midpoint label spacing.
fn edge_mid_label_metrics_for_rank_heights(
  edge : @cgraph.Edge,
) -> @rank_assignment.EdgeMidLabelMetrics? {
  match @label_metrics.edge_mid_label_metrics(edge) {
    Some(metrics) =>
      Some(@rank_assignment.make_edge_mid_label_metrics(metrics.width, metrics.height))
    None => None
  }
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_stage_deps() -> OrderingStageDeps {
  {
    edge_mid_label_metrics_for: edge =>
      match @label_metrics.edge_mid_label_metrics(edge) {
        Some(value) => Some((value.width, value.height))
        None => None
      },
    build_edge_port_sample_bundle:
      (nodes, edges, edge_tail, edge_head, order_sizes) =>
        @positioning.build_edge_port_sample_bundle(
          nodes,
          edges,
          edge_tail,
          edge_head,
          order_sizes,
          port_offsets_for_nodes,
          edge_port_offset,
          edge_port_order,
        ),
  }
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_rank_stage(
  input : DotRankStageInput,
) -> DotRankStageOutput {
  let graph = input.graph
  let prep = input.prep
  // Graphviz parity: rank-data creation remains first before downstream stage assembly.
  let rank_data =
    @rank_assignment.compute_rank_data(
      @rank_assignment.make_rank_data_input(
        graph,
        prep.nodes,
        prep.edges,
        prep.has_edge_labels,
        CL_BACK,
        @label_metrics.edge_label_height_pt,
      ),
    )
  // Graphviz parity: rank-height stage consumes computed ranks/groups
  // and spacing inputs with unchanged Graphviz argument wiring.
  let rank_heights =
    @rank_assignment.compute_rank_heights(
      @rank_assignment.make_rank_heights_input(
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
        VNODE_HEIGHT_PT,
        edge_mid_label_metrics_for_rank_heights,
        cluster_label_padding_for_layout,
      ),
    )
  // Graphviz parity: ordering stage owns cluster-metadata preparation plus
  // vnode ordering dispatch; the root stage only passes rank/order inputs and
  // root-owned deps across the package boundary.
  let ordering_stage_output : OrderingStageOutput =
    @ordering_stage.compute_ordering_stage(
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
        port_order_positions: prep.port_order_positions,
        port_order_contrib: prep.port_order_contrib,
      },
      build_ordering_stage_deps(),
    )
  let cluster_meta = ordering_stage_output.cluster_meta
  let ordering = ordering_stage_output.ordering
  // Graphviz parity: rank-stage result object keeps computed
  // rank/cluster/order artifacts unchanged.
  { rank_data, rank_heights, cluster_meta, ordering }
}
