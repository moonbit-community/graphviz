///|
fn sample_pipeline_sources(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  has_vnode_order : Bool,
  ordering_set : Bool,
  has_clusters : Bool,
) -> XposReorderPipelineSources {
  let x_groups : Map[Int, Array[String]] = { 0: ["a", "b"] }
  let x_order_sizes : Map[String, @node_primitives.NodeSize] = {
    "a": sample_node_size(10.0, 10.0),
  }
  {
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder: true,
    has_vnode_order,
    ordering_set,
    has_clusters,
    x_groups,
    x_order_sizes,
    x_cluster_keys: Map::new(),
    cluster_min_rank: Map::new(),
    cluster_max_rank: Map::new(),
    node_order: Map::new(),
    cluster_skeleton_size: sample_node_size(2.0, 2.0),
    edges: [],
    edge_tail: [],
    edge_head: [],
    ranks: Map::new(),
    edge_vnodes: Map::new(),
    vnode_ranks: Map::new(),
    edge_tail_port_x: [],
    edge_head_port_x: [],
    edge_tail_port_order: [],
    edge_head_port_order: [],
    cluster_skeleton_penalty: 1,
    rank_same_groups: Map::new(),
    rank_same_order: Map::new(),
    nodesep_pt: 18.0,
    has_edge_labels: false,
    flat_constraints: Map::new(),
    graphviz_flip: false,
    nodes: [],
    order_edges: [],
    order_edge_tail: [],
    order_edge_head: [],
    order_edge_tail_port_x: [],
    order_edge_head_port_x: [],
    order_edge_tail_port_order: [],
    order_edge_head_port_order: [],
    edge_order: Map::new(),
    port_order_positions: Map::new(),
    port_order_contrib: Map::new(),
    cluster_skeleton: Map::new(),
    transpose_max_passes: 2,
  }
}

///|
test "build_xpos_reorder_path_flags separates clustered and nonclustered eligibility" {
  let nonclustered = build_xpos_reorder_path_flags(
    sample_pipeline_sources(true, false, false, false, false),
  )
  assert_false(nonclustered.clustered_reorder_enabled)
  assert_true(nonclustered.nonclustered_reorder_enabled)

  let clustered = build_xpos_reorder_path_flags(
    sample_pipeline_sources(true, true, false, false, true),
  )
  assert_true(clustered.clustered_reorder_enabled)
  assert_false(clustered.nonclustered_reorder_enabled)

  let disabled = build_xpos_reorder_path_flags(
    sample_pipeline_sources(true, false, false, true, false),
  )
  assert_false(disabled.clustered_reorder_enabled)
  assert_false(disabled.nonclustered_reorder_enabled)
}
