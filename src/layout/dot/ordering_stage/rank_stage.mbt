///|
/// Dot-owned bridge logic for Stage B rank/order pipeline assembly.

type LayoutPrep = @shared.LayoutPrep
type RankData = @rank_assignment.RankData
type RankHeights = @rank_assignment.RankHeights

///|
/// Graphviz parity: rank stage payload keeps Stage A-prepared inputs grouped
/// so Stage B wiring remains explicit and stable.
pub(all) struct RankStageInput {
  graph : @cgraph.Graph
  prep : LayoutPrep
}

///|
/// Graphviz parity: stage-B output keeps rank, cluster, and ordering artifacts
/// grouped for downstream position/routing stages.
pub(all) struct RankStageOutput {
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
  match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(metrics) =>
      Some(@rank_assignment.make_edge_mid_label_metrics(metrics.width, metrics.height))
    None => None
  }
}

///|
/// Graphviz parity: dot rank/order stage mirrors refs/graphviz/lib/dotgen
/// (dotinit.c, rank.c, mincross.c, flat.c, position.c), with typed stage inputs.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_dot_rank_stage(
  input : RankStageInput,
) -> RankStageOutput {
  let graph = input.graph
  let prep = input.prep
  let rank_data =
    @rank_assignment.compute_rank_data(
      @rank_assignment.make_rank_data_input(
        graph,
        prep.nodes,
        prep.edges,
        prep.has_edge_labels,
        @rank_assignment.CL_BACK,
        @edge_label_metrics.edge_label_height_pt,
      ),
    )
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
        @node_primitives.VNODE_HEIGHT_PT,
        edge_mid_label_metrics_for_rank_heights,
        @clustering.cluster_label_padding_for_layout,
      ),
    )
  let ordering_stage_output =
    compute_ordering_stage(
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
    )
  {
    rank_data,
    rank_heights,
    cluster_meta: ordering_stage_output.cluster_meta,
    ordering: ordering_stage_output.ordering,
  }
}
