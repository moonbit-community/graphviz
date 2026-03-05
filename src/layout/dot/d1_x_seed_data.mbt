///|
/// Stage D Phase D1 split: x-stage seed data helpers.

///|
priv struct XposOrderEdgePortData {
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
}

///|
priv struct XPositionSeedData {
  has_vnode_order : Bool
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: x-stage seed input keeps vnode mode plus ordering/rank
/// context grouped before order-index, vnode-order, and edge-port precompute.
priv struct XSeedBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
/// Graphviz parity: x-order edge-port payload keeps vnode-mode and stage
/// pipeline context grouped before port sampling and vnode-size merge.
priv struct XOrderEdgePortBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
/// Graphviz parity: x-order sizes and edge port position/order arrays are
/// derived from layout-coordinate sizes before any xpos reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_x_order_edge_port_data(
  input : XOrderEdgePortBuildInput,
) -> XposOrderEdgePortData {
  let pipeline = input.pipeline
  let prep = pipeline.prep
  let rank_data = pipeline.rank_data
  let ordering = pipeline.ordering
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if input.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_edge_port_x_samples =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_x = x_edge_port_x_samples.tail_values
  let x_edge_head_port_x = x_edge_port_x_samples.head_values
  let x_edge_port_order_samples =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_order = x_edge_port_order_samples.tail_values
  let x_edge_head_port_order = x_edge_port_order_samples.head_values
  {
    x_base_sizes,
    x_order_sizes,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  }
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  input : XSeedBuildInput,
) -> XPositionSeedData {
  let pipeline = input.pipeline
  let order_index = @ordering.build_order_index(pipeline.ordering.ordered_groups)
  let vnode_order_state =
    @positioning.build_vnode_order_state(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
        edges: pipeline.prep.edges,
        edge_tail: pipeline.rank_data.edge_tail,
        edge_head: pipeline.rank_data.edge_head,
        edge_reversed: pipeline.rank_data.edge_reversed,
        ranks: pipeline.rank_data.ranks,
        order_index,
        intercluster_keys: pipeline.cluster_meta.intercluster_keys,
        cluster_parents: pipeline.cluster_meta.cluster_parents,
        edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
        vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      },
    )
  let has_vnode_order = vnode_order_state.has_vnode_order
  let x_order_edge_port_data =
    build_x_order_edge_port_data(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        pipeline,
      },
    )
  let x_groups =
    @positioning.build_initial_x_groups(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        ordered_groups: pipeline.ordering.ordered_groups,
        ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
        order_index,
        vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
        vnode_order_keys: vnode_order_state.vnode_order_keys,
        has_clusters: pipeline.cluster_meta.has_clusters,
        is_cluster_skeleton_name:
          (name) => cluster_key_from_skeleton(name) is Some(_),
      },
    )
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in pipeline.cluster_meta.cluster_keys {
    x_cluster_keys[name] = key
  }
  if input.use_vnodes_for_xpos {
    for name, key in pipeline.ordering.vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  {
    has_vnode_order,
    x_base_sizes: x_order_edge_port_data.x_base_sizes,
    x_order_sizes: x_order_edge_port_data.x_order_sizes,
    x_edge_tail_port_x: x_order_edge_port_data.x_edge_tail_port_x,
    x_edge_head_port_x: x_order_edge_port_data.x_edge_head_port_x,
    x_edge_tail_port_order: x_order_edge_port_data.x_edge_tail_port_order,
    x_edge_head_port_order: x_order_edge_port_data.x_edge_head_port_order,
    x_groups,
    x_cluster_keys,
  }
}
