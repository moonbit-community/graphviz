///|
type ConstraintEdge = @x_constraints.ConstraintEdge

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

