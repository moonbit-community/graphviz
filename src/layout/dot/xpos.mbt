///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn cluster_label_borders_for_xpos_constraints(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> (Double, Double) {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if !flip {
    return (0.0, 0.0)
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let border = metrics.height_pt + CLUSTER_LABEL_PAD_PT
      match graph_label_loc(graph) {
        LabelLoc::Top => (0.0, border)
        LabelLoc::Bottom => (border, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
/// Graphviz parity: xpos payload keeps rank/group/cluster snapshots grouped so
/// position.c/cluster.c constraint wiring remains explicit and stable.
type XPositionsInput = @positioning.XPositionSolveInput

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions(
  input : XPositionsInput,
) -> Map[String, Double] {
  let graph = input.graph
  let prepared =
    @positioning.prepare_xpos_constraint_inputs(
      graph,
      input.nodes,
      input.edges,
      input.ranks,
      input.rank_keys,
      input.groups,
      input.sizes,
      input.cluster_keys,
      input.nodesep_pt,
      input.has_edge_labels,
      input.edge_vnodes,
      input.extra_nodes,
      input.flat_label_edges,
      {
        cluster_label_borders_for: cluster_label_borders_for_xpos_constraints,
        cluster_label_width_with_pad_for: cluster_label_width_with_pad_for_layout,
        cluster_compact_weight: CLUSTER_COMPACT_WEIGHT,
      },
    )
  x_positions_from_simplex(
    {
      graph_root: graph,
      nodes: input.nodes,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      edge_out_order: input.edge_out_order,
      nlist_order: input.nlist_order,
      gdnlist_order: input.gdnlist_order,
      ranks: input.ranks,
      rank_keys: input.rank_keys,
      groups: input.groups,
      sizes: input.sizes,
      output_sizes: input.output_sizes,
      cluster_keys: input.cluster_keys,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      extra_nodes: prepared.extra_nodes,
      extra_edges: prepared.extra_edges,
      edge_vnodes: input.edge_vnodes,
      root_ln_targets: prepared.root_ln_targets,
      root_rn_targets: prepared.root_rn_targets,
      compress_width_minlen: prepared.compress_width_minlen,
    },
  )
}
