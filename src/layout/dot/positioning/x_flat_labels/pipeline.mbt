///|
type ConstraintEdge = @x_constraints.ConstraintEdge

///|
/// Graphviz parity: flat-label vnode augmentation keeps x-groups, injected
/// label edges, rank overlays, and vnode cluster-key overlay grouped for one
/// positioning-stage augmentation pass.
priv struct FlatLabelVnodeBuildOutput {
  x_groups : Map[Int, Array[String]]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_ranks : Map[String, Int]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: x-flat-label augmentation input keeps vnode-xpos gate,
/// node/vnode snapshots, and mutable x-group/cluster-key state grouped before
/// one augmentation pass.
priv struct XFlatLabelAugmentationInput {
  use_vnodes_for_xpos : Bool
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  nodes : Array[@cgraph.Node]
  vnode_ranks : Map[String, Int]
  vnode_clusters : Map[String, String]
  build_flat_label_vnodes_fn : (
    Map[String, Bool],
    Map[Int, Array[String]],
  ) -> FlatLabelVnodeBuildOutput
}

///|
pub(all) struct XFlatLabelAugmentationOutput {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_ranks : Map[String, Int]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: x-flat-label positioning pipeline sources keep reorder
/// flags, seed snapshots, cluster metadata, and flat-label vnode inputs grouped
/// so Stage D can delegate one cohesive owner-package pass.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct XFlatLabelPositioningPipelineSources {
  xpos_reorder_enabled : Bool
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
  has_vnode_order : Bool
  ordering_set : Bool
  has_clusters : Bool
  x_groups : Map[Int, Array[String]]
  x_base_sizes : Map[String, @node_primitives.NodeSize]
  x_order_sizes : Map[String, @node_primitives.NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
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
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  flat_constraints : Map[String, Bool]
  nodes : Array[@cgraph.Node]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  edge_order : Map[String, Int]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_skeleton : Map[String, Bool]
  vnode_clusters : Map[String, String]
  ordered_groups : Map[Int, Array[String]]
  rankdir : @rankdir.RankDir
  edge_cluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  vnode_info : @routing.EdgeVnodeInfo
}

///|
/// Graphviz parity: x-flat-label reorder pipeline input keeps reorder sources
/// plus augmentation callback grouped so reorder/transpose cleanup always runs
/// before flat-label vnode injection.
priv struct XFlatLabelPipelineInput {
  reorder_sources : @x_reorder.XposReorderPipelineSources
  augment_from_groups_fn : (Map[Int, Array[String]]) -> XFlatLabelAugmentationOutput
}

const CLUSTER_SKELETON_PENALTY : Int = 1000

const TRANSPOSE_MAX_PASSES : Int = 4

///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, rank overlays, and vnode cluster-key overlay only on
/// vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_label_augmentation(
  input : XFlatLabelAugmentationInput,
) -> XFlatLabelAugmentationOutput {
  let mut next_x_groups = input.x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_ranks : Map[String, Int] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = input.x_cluster_keys
  if input.use_vnodes_for_xpos {
    let existing_names : Map[String, Bool] = Map::new()
    for node in input.nodes {
      existing_names[node.name()] = true
    }
    for vnode, _ in input.vnode_ranks {
      existing_names[vnode] = true
    }
    let flat_label_vnodes =
      (input.build_flat_label_vnodes_fn)(existing_names, next_x_groups)
    next_x_groups = flat_label_vnodes.x_groups
    flat_label_edges = flat_label_vnodes.flat_label_edges
    flat_label_ranks = flat_label_vnodes.flat_label_ranks
    flat_label_edge_vnodes = flat_label_vnodes.flat_label_edge_vnodes
    for name, key in input.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_ranks,
    flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: positioning-owned x-flat-label reorder sources keep field
/// ordering and values unchanged before clustered/non-clustered reorder
/// dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_positioning_x_flat_label_reorder_sources(
  sources : XFlatLabelPositioningPipelineSources,
) -> @x_reorder.XposReorderPipelineSources {
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
    cluster_skeleton_size: @node_primitives.vnode_size_from_widths(1.0, 1.0),
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
    cluster_skeleton_penalty: CLUSTER_SKELETON_PENALTY,
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
    order_edge_tail_port_x: sources.order_edge_tail_port_x,
    order_edge_head_port_x: sources.order_edge_head_port_x,
    order_edge_tail_port_order: sources.order_edge_tail_port_order,
    order_edge_head_port_order: sources.order_edge_head_port_order,
    edge_order: sources.edge_order,
    port_order_positions: sources.port_order_positions,
    port_order_contrib: sources.port_order_contrib,
    cluster_skeleton: sources.cluster_skeleton,
    transpose_max_passes: TRANSPOSE_MAX_PASSES,
  }
}

///|
/// Graphviz parity: x-flat-label augmentation after reorder/transpose cleanup
/// builds flat-label vnodes only on vnode-xpos path and preserves the same
/// edge/cluster ordering inputs as before.
/// Do not change behavior without updating fixtures/tests.
fn build_positioning_x_flat_label_augmentation(
  sources : XFlatLabelPositioningPipelineSources,
  x_groups : Map[Int, Array[String]],
) -> XFlatLabelAugmentationOutput {
  build_x_flat_label_augmentation(
    {
      use_vnodes_for_xpos: sources.use_vnodes_for_xpos,
      x_groups,
      x_cluster_keys: sources.x_cluster_keys,
      nodes: sources.nodes,
      vnode_ranks: sources.vnode_ranks,
      vnode_clusters: sources.vnode_clusters,
      build_flat_label_vnodes_fn:
        (existing_names, x_groups) =>
          build_flat_label_vnodes_for_positioning(
            sources.edges,
            sources.edge_tail,
            sources.edge_head,
            sources.ranks,
            sources.ordered_groups,
            sources.nodesep_pt,
            sources.rankdir,
            sources.x_base_sizes,
            sources.edge_cluster_keys,
            sources.cluster_parents,
            existing_names,
            sources.vnode_info,
            x_groups,
          ),
    },
  )
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as
/// Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_label_pipeline(
  input : XFlatLabelPipelineInput,
) -> XFlatLabelAugmentationOutput {
  let x_groups =
    @x_reorder.build_x_groups_after_reorder(
      input.reorder_sources,
    )
  (input.augment_from_groups_fn)(x_groups)
}

///|
/// Graphviz parity: positioning-owned x-flat-label pipeline keeps reorder,
/// transpose cleanup, and flat-label augmentation inside the owner package so
/// Stage D only provides stage snapshots.
/// Do not change behavior without updating fixtures/tests.
pub fn build_positioning_x_flat_label_pipeline(
  sources : XFlatLabelPositioningPipelineSources,
) -> XFlatLabelAugmentationOutput {
  let reorder_sources =
    build_positioning_x_flat_label_reorder_sources(sources)
  build_x_flat_label_pipeline(
    {
      reorder_sources,
      augment_from_groups_fn:
        (x_groups) =>
          build_positioning_x_flat_label_augmentation(sources, x_groups),
    },
  )
}
