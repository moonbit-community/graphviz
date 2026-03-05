///|
/// Stage D Phase D1 split: x-stage seed data helpers.

///|
/// Graphviz parity: x-stage seed input keeps vnode mode plus ordering/rank
/// context grouped before order-index, vnode-order, and edge-port precompute.
priv struct XSeedBuildInput {
  use_vnodes_for_xpos : Bool
  pipeline : PositionPipelineContext
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  input : XSeedBuildInput,
) -> @positioning.XPositionSeedData {
  let pipeline = input.pipeline
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
      nodes: pipeline.prep.nodes,
      sizes: pipeline.prep.sizes,
      vnode_sizes: pipeline.ordering.vnode_info.vnode_sizes,
      apply_size_adjustment_fn: (nodes, edges, sizes) =>
        apply_self_edge_right_space(
          nodes,
          edges,
          sizes,
          pipeline.prep.rankdir,
          pipeline.prep.record_orientation,
        ),
      compute_port_positions_fn: compute_edge_port_values,
      compute_port_orders_fn: compute_edge_order_values,
      vnodes_by_rank: pipeline.ordering.vnode_info.vnodes_by_rank,
      has_clusters: pipeline.cluster_meta.has_clusters,
      is_cluster_skeleton_name:
        (name) => cluster_key_from_skeleton(name) is Some(_),
      cluster_keys: pipeline.cluster_meta.cluster_keys,
      vnode_clusters: pipeline.ordering.vnode_info.vnode_clusters,
    },
  )
}

///|
fn compute_edge_port_values(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  let samples =
    compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
  (samples.tail_values, samples.head_values)
}

///|
fn compute_edge_order_values(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  let samples =
    compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
  (samples.tail_values, samples.head_values)
}
