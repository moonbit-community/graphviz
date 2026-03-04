///|
/// Stage D Phase D5 split: x-position solver input assembly and invocation.

///|
priv struct XposComputationInput {
  x_sizes : Map[String, NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: x-position solve input keeps x-stage bundle plus ordering
/// and rank context grouped for one compute_x_positions invocation.
priv struct XPositionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
/// Graphviz parity: xpos solver inputs must preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input(
  input : XPositionBuildInput,
) -> XposComputationInput {
  let x_sizes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(
        input.x_data.x_base_sizes,
        input.pipeline.ordering.vnode_info.vnode_sizes,
      )
    } else {
      input.x_data.x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(input.x_data.x_groups)
  let x_ranks = @ordering.build_node_ranks(input.x_data.x_groups)
  let vnode_extra_nodes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        input.pipeline.ordering.vnode_creation_order,
        input.pipeline.ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if input.x_data.use_vnodes_for_xpos {
      input.pipeline.ordering.vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  input : XPositionBuildInput,
) -> Map[String, Double] {
  let xpos_input = build_xpos_computation_input(input)
  let x_positions = compute_x_positions(
    input.pipeline.graph,
    input.pipeline.prep.nodes,
    input.pipeline.prep.edges,
    input.pipeline.rank_data.edge_tail,
    input.pipeline.rank_data.edge_head,
    input.pipeline.rank_data.edge_out_order,
    input.pipeline.ordering.nlist_order,
    input.pipeline.ordering.gdnlist_order,
    xpos_input.x_ranks,
    xpos_input.x_rank_keys,
    input.x_data.x_groups,
    xpos_input.x_sizes,
    input.pipeline.prep.output_sizes,
    input.x_data.x_cluster_keys,
    input.pipeline.rank_heights.nodesep_pt,
    input.pipeline.prep.has_edge_labels,
    xpos_input.x_extra_nodes,
    input.x_data.flat_label_edges,
    xpos_input.x_edge_vnodes,
  )
  x_positions
}
