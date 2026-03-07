///|
/// Stage D x-stage seed data helpers.

///|
/// Graphviz parity: x-stage seed input keeps vnode mode plus ordering/rank
/// context grouped before order-index, vnode-order, and edge-port precompute.
priv struct XSeedBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
fn build_x_order_sizes(
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  if use_vnodes_for_xpos {
    @ordering.merge_sizes_with_vnodes(
      x_base_sizes,
      vnode_sizes,
    )
  } else {
    x_base_sizes
  }
}

///|
/// Graphviz parity: x-seed edge-port samples keep main-edge and order-edge
/// tail/head x+order arrays grouped in Graphviz-compatible construction order.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_port_samples(
  pipeline : PositionPipelineContext,
  x_order_sizes : Map[String, NodeSize],
) -> @positioning.XSeedPortSamples {
  let build_port_sample_bundle =
    (edges, edge_tail, edge_head) =>
      @positioning.build_edge_port_sample_bundle(
        pipeline.prep.nodes,
        edges,
        edge_tail,
        edge_head,
        x_order_sizes,
        @port_bridge.port_offsets_for_nodes,
        @port_bridge.edge_port_offset,
        @port_bridge.edge_port_order,
      )
  let x_port_samples =
    build_port_sample_bundle(
      pipeline.prep.edges,
      pipeline.rank_data.edge_tail,
      pipeline.rank_data.edge_head,
    )
  let order_edge_port_samples =
    build_port_sample_bundle(
      pipeline.ordering.order_edges,
      pipeline.ordering.order_edge_tail,
      pipeline.ordering.order_edge_head,
    )
  {
    x_edge_tail_port_x: x_port_samples.tail_port_x,
    x_edge_head_port_x: x_port_samples.head_port_x,
    x_edge_tail_port_order: x_port_samples.tail_port_order,
    x_edge_head_port_order: x_port_samples.head_port_order,
    order_edge_tail_port_x: order_edge_port_samples.tail_port_x,
    order_edge_head_port_x: order_edge_port_samples.head_port_x,
    order_edge_tail_port_order: order_edge_port_samples.tail_port_order,
    order_edge_head_port_order: order_edge_port_samples.head_port_order,
  }
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  input : XSeedBuildInput,
) -> @positioning.XPositionSeedData {
  let pipeline = input.pipeline
  let x_base_sizes =
    @port_bridge.apply_self_edge_right_space(
      pipeline.prep.nodes,
      pipeline.prep.edges,
      pipeline.prep.sizes,
      pipeline.prep.rankdir,
      pipeline.prep.record_orientation,
    )
  let x_order_sizes =
    build_x_order_sizes(
      input.use_vnodes_for_xpos,
      x_base_sizes,
      pipeline.ordering.vnode_info.vnode_sizes,
    )
  let port_samples =
    build_x_seed_port_samples(pipeline, x_order_sizes)
  @positioning.build_x_seed_data_from_sources(
    {
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      ordered_groups: pipeline.ordering.ordered_groups,
      ordered_groups_with_vnodes: pipeline.ordering.ordered_groups_with_vnodes,
      edges: pipeline.prep.edges,
      edge_tail: pipeline.rank_data.edge_tail,
      edge_head: pipeline.rank_data.edge_head,
      edge_reversed: pipeline.rank_data.edge_reversed,
      ranks: pipeline.rank_data.ranks,
      intercluster_keys: pipeline.cluster_meta.intercluster_keys,
      cluster_parents: pipeline.cluster_meta.cluster_parents,
      edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
      vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      x_base_sizes,
      x_order_sizes,
      port_samples,
      vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
      has_clusters: pipeline.cluster_meta.has_clusters,
      cluster_keys: pipeline.cluster_meta.cluster_keys,
      vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
    },
  )
}
