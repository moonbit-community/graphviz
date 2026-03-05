///|
/// Stage D Phase D3 split: x-stage flat-label augmentation helpers.

///|
/// Graphviz parity: flat-label augmentation input keeps x-stage pipeline,
/// vnode-xpos gate, and mutable x-group/cluster-key snapshots grouped for one
/// augmentation pass.
priv struct FlatLabelAugmentationBuildInput {
  pipeline : PositionPipelineContext
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
priv struct XposFlatLabelAugmentation {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation(
  input : FlatLabelAugmentationBuildInput,
) -> XposFlatLabelAugmentation {
  let pipeline = input.pipeline
  let mut next_x_groups = input.x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = input.x_cluster_keys
  let existing_names : Map[String, Bool] = Map::new()
  for node in pipeline.prep.nodes {
    existing_names[node.name()] = true
  }
  for vnode, _ in pipeline.ordering.vnode_info.vnode_ranks {
    existing_names[vnode] = true
  }
  if input.use_vnodes_for_xpos {
    let flat_label_vnodes = add_flat_label_vnodes(
      pipeline.prep.edges,
      pipeline.rank_data.edge_tail,
      pipeline.rank_data.edge_head,
      pipeline.rank_data.ranks,
      pipeline.ordering.ordered_groups,
      pipeline.rank_heights.nodesep_pt,
      pipeline.prep.rankdir,
      input.x_base_sizes,
      pipeline.ordering.edge_cluster_keys,
      pipeline.cluster_meta.cluster_parents,
      existing_names,
      pipeline.ordering.vnode_info,
      next_x_groups,
    )
    next_x_groups = flat_label_vnodes.x_groups
    flat_label_edges = flat_label_vnodes.flat_label_edges
    flat_label_nodes = flat_label_vnodes.flat_label_nodes
    flat_label_edge_vnodes = flat_label_vnodes.flat_label_edge_vnodes
    for name, key in pipeline.ordering.vnode_info.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_nodes,
    flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_labels(
  input : XFlatLabelBuildInput,
) -> XposFlatLabelAugmentation {
  let x_groups =
    @positioning.build_x_groups_after_reorder(
      build_xpos_reorder_pipeline_input(input),
      (sample_input) =>
        @positioning.build_xpos_port_samples(
          sample_input,
          compute_edge_port_values,
          compute_edge_order_values,
        ),
    )
  build_flat_label_augmentation(
    {
      pipeline: input.pipeline,
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      x_base_sizes: input.x_seed.x_base_sizes,
      x_groups,
      x_cluster_keys: input.x_seed.x_cluster_keys,
    },
  )
}
