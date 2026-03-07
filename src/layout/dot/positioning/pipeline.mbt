///|
type ConstraintEdge = @x_constraints.ConstraintEdge

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
/// Graphviz parity: position stage result keeps x/y coordinates, vnode
/// positions, and cluster bbox metadata grouped for downstream stages.
pub(all) struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, @clustering.ClusterBboxHeightPair]
}

///|
pub(all) struct FlatLabelVnodeBuildOutput {
  x_groups : Map[Int, Array[String]]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_ranks : Map[String, Int]
  flat_label_edge_vnodes : Map[String, String]
}

///|
pub(all) struct XFlatLabelAugmentationInput {
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
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, rank overlays, and vnode cluster-key overlay only on
/// vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_flat_label_augmentation(
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
pub(all) struct XFlatLabelPipelineInput {
  reorder_sources : @x_reorder.XposReorderPipelineSources
  augment_from_groups_fn : (Map[Int, Array[String]]) -> XFlatLabelAugmentationOutput
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_flat_label_pipeline(
  input : XFlatLabelPipelineInput,
) -> XFlatLabelAugmentationOutput {
  let x_groups =
    @x_reorder.build_x_groups_after_reorder(
      input.reorder_sources,
    )
  (input.augment_from_groups_fn)(x_groups)
}

