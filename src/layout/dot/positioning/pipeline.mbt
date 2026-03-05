///|
/// Graphviz parity: clustered/non-clustered xpos reorder branch gates are
/// evaluated once and then reused by reorder + transpose cleanup.
priv struct XposReorderPathFlags {
  clustered_reorder_enabled : Bool
  nonclustered_reorder_enabled : Bool
}

///|
/// Graphviz parity: xpos reorder pipeline input keeps branch gates plus
/// clustered/non-clustered reorder payload grouped for one reorder+transpose
/// pass.
pub struct XposReorderPipelineInput {
  xpos_reorder_enabled : Bool
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  has_vnode_order : Bool
  ordering_set : Bool
  has_clusters : Bool
  x_groups : Map[Int, Array[String]]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
  cluster_skeleton_prefix : String
  cluster_skeleton_size : @shared.NodeSize
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  cluster_skeleton_penalty : Int
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
  nodes : Array[@cgraph.Node]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_skeleton : Map[String, Bool]
  transpose_max_passes : Int
}

///|
pub fn build_xpos_reorder_pipeline_input(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  ordering_set : Bool,
  has_clusters : Bool,
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, @shared.NodeSize],
  x_cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  node_order : Map[String, Int],
  cluster_skeleton_prefix : String,
  cluster_skeleton_size : @shared.NodeSize,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  cluster_skeleton_penalty : Int,
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodes : Array[@cgraph.Node],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  edge_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_skeleton : Map[String, Bool],
  transpose_max_passes : Int,
) -> XposReorderPipelineInput {
  {
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    has_vnode_order,
    ordering_set,
    has_clusters,
    x_groups,
    x_order_sizes,
    x_cluster_keys,
    cluster_min_rank,
    cluster_max_rank,
    node_order,
    cluster_skeleton_prefix,
    cluster_skeleton_size,
    edges,
    edge_tail,
    edge_head,
    ranks,
    edge_vnodes,
    vnode_ranks,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    cluster_skeleton_penalty,
    rank_same_groups,
    rank_same_order,
    nodesep_pt,
    has_edge_labels,
    flat_constraints,
    graphviz_flip,
    nodes,
    order_edges,
    order_edge_tail,
    order_edge_head,
    edge_order,
    port_order_positions,
    port_order_contrib,
    cluster_skeleton,
    transpose_max_passes,
  }
}

///|
/// Graphviz parity: reorder branch gating is evaluated once so clustered and
/// non-clustered paths consume identical predicates as transpose cleanup.
fn build_xpos_reorder_path_flags(
  input : XposReorderPipelineInput,
) -> XposReorderPathFlags {
  let base_reorder_enabled =
    input.xpos_reorder_enabled &&
    input.allow_xpos_reorder &&
    !input.ordering_set
  {
    clustered_reorder_enabled:
      base_reorder_enabled && input.use_vnodes_for_xpos,
    nonclustered_reorder_enabled:
      base_reorder_enabled &&
      !input.has_vnode_order &&
      !input.has_clusters,
  }
}

///|
/// Graphviz parity: clustered xpos reorder path keeps the same order-edge
/// materialization and reorder_rank_groups input ordering as Graphviz.
fn apply_clustered_xpos_reorder_path(
  input : XposReorderPipelineInput,
) -> Map[Int, Array[String]] {
  build_clustered_xpos_groups(
    {
      x_groups: input.x_groups,
      x_order_sizes: input.x_order_sizes,
      x_cluster_keys: input.x_cluster_keys,
      cluster_min_rank: input.cluster_min_rank,
      cluster_max_rank: input.cluster_max_rank,
      node_order: input.node_order,
      cluster_skeleton_prefix: input.cluster_skeleton_prefix,
      cluster_skeleton_size: input.cluster_skeleton_size,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      ranks: input.ranks,
      edge_vnodes: input.edge_vnodes,
      edge_tail_port_x: input.edge_tail_port_x,
      edge_head_port_x: input.edge_head_port_x,
      edge_tail_port_order: input.edge_tail_port_order,
      edge_head_port_order: input.edge_head_port_order,
      cluster_skeleton_penalty: input.cluster_skeleton_penalty,
      rank_same_groups: input.rank_same_groups,
      rank_same_order: input.rank_same_order,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      flat_constraints: input.flat_constraints,
      graphviz_flip: input.graphviz_flip,
    },
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder fallback runs only when clustered
/// vnode reorder path is not taken, matching Graphviz branch structure.
fn apply_nonclustered_xpos_reorder(
  input : XposReorderPipelineInput,
  compute_port_samples : XposPortSampleBundleFn,
) -> Map[Int, Array[String]] {
  build_nonclustered_xpos_groups(
    {
      nodes: input.nodes,
      order_edges: input.order_edges,
      order_edge_tail: input.order_edge_tail,
      order_edge_head: input.order_edge_head,
      ranks: input.ranks,
      edge_vnodes: input.edge_vnodes,
      vnode_ranks: input.vnode_ranks,
      x_cluster_keys: input.x_cluster_keys,
      rank_same_groups: input.rank_same_groups,
      rank_same_order: input.rank_same_order,
      edge_order: input.edge_order,
      node_order: input.node_order,
      x_order_sizes: input.x_order_sizes,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      port_order_positions: input.port_order_positions,
      port_order_contrib: input.port_order_contrib,
      cluster_skeleton: input.cluster_skeleton,
      flat_constraints: input.flat_constraints,
      graphviz_flip: input.graphviz_flip,
    },
    input.x_groups,
    compute_port_samples,
  )
}

///|
/// Graphviz parity: optional transpose cleanup runs only in vnode xpos-reorder
/// mode after reorder_rank_groups, and mutates x_groups in-place.
fn maybe_apply_xpos_transpose_cleanup(
  path_flags : XposReorderPathFlags,
  input : XposReorderPipelineInput,
  x_groups : Map[Int, Array[String]],
) -> Unit {
  if path_flags.clustered_reorder_enabled {
    apply_xpos_transpose_cleanup(
      x_groups,
      {
        nodes: input.nodes,
        order_edges: input.order_edges,
        order_edge_tail: input.order_edge_tail,
        order_edge_head: input.order_edge_head,
        ranks: input.ranks,
        edge_vnodes: input.edge_vnodes,
        vnode_ranks: input.vnode_ranks,
      },
      input.transpose_max_passes,
    )
  }
}

///|
/// Graphviz parity: xpos reorder and transpose-cleanup are applied in fixed
/// order before flat-label augmentation consumes updated x_groups.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_groups_after_reorder(
  input : XposReorderPipelineInput,
  compute_port_samples : XposPortSampleBundleFn,
) -> Map[Int, Array[String]] {
  let path_flags = build_xpos_reorder_path_flags(input)
  let x_groups =
    if path_flags.clustered_reorder_enabled {
      apply_clustered_xpos_reorder_path(input)
    } else if path_flags.nonclustered_reorder_enabled {
      apply_nonclustered_xpos_reorder(
        input,
        compute_port_samples,
      )
    } else {
      input.x_groups
    }
  maybe_apply_xpos_transpose_cleanup(path_flags, input, x_groups)
  x_groups
}
