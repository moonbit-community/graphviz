///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from precomputed stage flags.
pub struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
}

///|
/// Graphviz parity: position-mode source bundle keeps vnode caps and rankdir
/// together so Stage D call-sites avoid positional argument drift.
pub(all) struct PositionModeFlagSources {
  has_edge_labels : Bool
  has_port_edges : Bool
  vnode_count : Int
  max_xpos_vnodes : Int
  max_xpos_reorder_vnodes : Int
  rankdir : @shared.RankDir
}

///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_position_mode_flags(
  sources : PositionModeFlagSources,
) -> PositionModeFlags {
  let use_vnodes_for_xpos =
    sources.has_edge_labels || sources.has_port_edges ||
    sources.vnode_count <= sources.max_xpos_vnodes
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || sources.vnode_count <= sources.max_xpos_reorder_vnodes
  let graphviz_flip =
    sources.rankdir == @shared.RankDir::LR || sources.rankdir == @shared.RankDir::RL
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: x-position solve input keeps reordered rank metadata,
/// vnode extra-node toggles, and size overlays grouped for one xpos call.
pub struct XposComputationInput {
  x_sizes : Map[String, @shared.NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: xpos source bundle keeps x-stage payload and vnode replay
/// metadata grouped so Stage D call-sites avoid positional drift.
pub(all) struct XposComputationInputSources {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @shared.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @shared.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: xpos solver inputs preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
pub fn build_xpos_computation_input_from_sources(
  sources : XposComputationInputSources,
) -> XposComputationInput {
  let x_sizes =
    if sources.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(
        sources.x_base_sizes,
        sources.vnode_sizes,
      )
    } else {
      sources.x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(sources.x_groups)
  let x_ranks = @ordering.build_node_ranks(sources.x_groups)
  let vnode_extra_nodes =
    if sources.use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        sources.vnode_creation_order,
        sources.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if sources.use_vnodes_for_xpos {
      sources.edge_vnodes
    } else {
      Map::new()
  }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: xpos solver callback input keeps one compute_x_positions
/// invocation payload grouped so stage wiring avoids positional drift.
pub(all) struct XPositionSolveInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, @shared.NodeSize]
  output_sizes : Map[String, @shared.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  flat_label_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: x-position pipeline input keeps x-seed + vnode replay
/// snapshots and one compute_x_positions callback payload at one boundary.
pub(all) struct XPositionPipelineInput {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @shared.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @shared.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  output_sizes : Map[String, @shared.NodeSize]
  flat_label_edges : Array[ConstraintEdge]
  compute_x_positions_fn : (XPositionSolveInput) -> Map[String, Double]
}

///|
/// Graphviz parity: x-position stage keeps vnode merge, rank derivation, and
/// compute_x_positions invocation order unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_position_pipeline(
  input : XPositionPipelineInput,
) -> Map[String, Double] {
  let xpos_input =
    build_xpos_computation_input_from_sources(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        x_base_sizes: input.x_base_sizes,
        x_groups: input.x_groups,
        vnode_sizes: input.vnode_sizes,
        vnode_creation_order: input.vnode_creation_order,
        vnode_ranks: input.vnode_ranks,
        edge_vnodes: input.edge_vnodes,
      },
    )
  (input.compute_x_positions_fn)(
    {
      graph: input.graph,
      nodes: input.nodes,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      edge_out_order: input.edge_out_order,
      nlist_order: input.nlist_order,
      gdnlist_order: input.gdnlist_order,
      ranks: xpos_input.x_ranks,
      rank_keys: xpos_input.x_rank_keys,
      groups: input.x_groups,
      sizes: xpos_input.x_sizes,
      output_sizes: input.output_sizes,
      cluster_keys: input.cluster_keys,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      extra_nodes: xpos_input.x_extra_nodes,
      flat_label_edges: input.flat_label_edges,
      edge_vnodes: xpos_input.x_edge_vnodes,
    },
  )
}

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
/// Graphviz parity: xpos reorder pipeline source bundle keeps all branch
/// gates and reorder payload grouped so call-sites avoid positional drift.
pub(all) struct XposReorderPipelineSources {
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
pub fn build_xpos_reorder_pipeline_input_from_sources(
  sources : XposReorderPipelineSources,
) -> XposReorderPipelineInput {
  {
    xpos_reorder_enabled: sources.xpos_reorder_enabled,
    use_vnodes_for_xpos: sources.use_vnodes_for_xpos,
    allow_xpos_reorder: sources.allow_xpos_reorder,
    has_vnode_order: sources.has_vnode_order,
    ordering_set: sources.ordering_set,
    has_clusters: sources.has_clusters,
    x_groups: sources.x_groups,
    x_order_sizes: sources.x_order_sizes,
    x_cluster_keys: sources.x_cluster_keys,
    cluster_min_rank: sources.cluster_min_rank,
    cluster_max_rank: sources.cluster_max_rank,
    node_order: sources.node_order,
    cluster_skeleton_size: sources.cluster_skeleton_size,
    edges: sources.edges,
    edge_tail: sources.edge_tail,
    edge_head: sources.edge_head,
    ranks: sources.ranks,
    edge_vnodes: sources.edge_vnodes,
    vnode_ranks: sources.vnode_ranks,
    edge_tail_port_x: sources.edge_tail_port_x,
    edge_head_port_x: sources.edge_head_port_x,
    edge_tail_port_order: sources.edge_tail_port_order,
    edge_head_port_order: sources.edge_head_port_order,
    cluster_skeleton_penalty: sources.cluster_skeleton_penalty,
    rank_same_groups: sources.rank_same_groups,
    rank_same_order: sources.rank_same_order,
    nodesep_pt: sources.nodesep_pt,
    has_edge_labels: sources.has_edge_labels,
    flat_constraints: sources.flat_constraints,
    graphviz_flip: sources.graphviz_flip,
    nodes: sources.nodes,
    order_edges: sources.order_edges,
    order_edge_tail: sources.order_edge_tail,
    order_edge_head: sources.order_edge_head,
    edge_order: sources.edge_order,
    port_order_positions: sources.port_order_positions,
    port_order_contrib: sources.port_order_contrib,
    cluster_skeleton: sources.cluster_skeleton,
    transpose_max_passes: sources.transpose_max_passes,
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
