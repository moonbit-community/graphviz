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

///|
test "build_x_groups_after_reorder returns source groups when reorder is disabled" {
  let output = build_x_groups_after_reorder(
    sample_pipeline_sources(false, false, false, false, false),
  )

  assert_eq(output.get(0), Some(["a", "b"]))
}

///|
test "build_x_groups_after_reorder uses nonclustered reorder path to remove a simple crossing" {
  let (graph, node_map) = new_test_graph(["a", "b", "x", "y"])
  let ax = graph.edge(node_map["a"], node_map["x"])
  let by = graph.edge(node_map["b"], node_map["y"])

  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  x_groups[1] = ["y", "x"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let x_order_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  x_order_sizes["a"] = sample_node_size(10.0, 10.0)
  x_order_sizes["b"] = sample_node_size(10.0, 10.0)
  x_order_sizes["x"] = sample_node_size(10.0, 10.0)
  x_order_sizes["y"] = sample_node_size(10.0, 10.0)

  let nodes = [node_map["a"], node_map["b"], node_map["x"], node_map["y"]]
  let order_edges = [ax, by]
  let order_edge_tail = ["a", "b"]
  let order_edge_head = ["x", "y"]
  let edge_in : Map[String, Array[Int]] = Map::new()
  edge_in["x"] = [0]
  edge_in["y"] = [1]
  let edge_out : Map[String, Array[Int]] = Map::new()
  let before_crossings = @reorder.count_rank_crossings_port(
    1,
    x_groups.get(1).unwrap_or([]),
    ranks,
    @rank_groups.build_order_index(x_groups),
    edge_in,
    edge_out,
    order_edge_tail,
    order_edge_head,
    [0.0, 0.0],
    [0.0, 0.0],
    [1, 1],
  )

  let output = build_x_groups_after_reorder({
    xpos_reorder_enabled: true,
    use_vnodes_for_xpos: false,
    allow_xpos_reorder: true,
    has_vnode_order: false,
    ordering_set: false,
    has_clusters: false,
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
    ranks,
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
    nodes,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x: [0.0, 0.0],
    order_edge_head_port_x: [0.0, 0.0],
    order_edge_tail_port_order: [0.5, 0.5],
    order_edge_head_port_order: [0.5, 0.5],
    edge_order: @order_graph.collect_edge_order(order_edges),
    port_order_positions: Map::new(),
    port_order_contrib: Map::new(),
    cluster_skeleton: Map::new(),
    transpose_max_passes: 2,
  })

  let after_crossings = @reorder.count_rank_crossings_port(
    1,
    output.get(1).unwrap_or([]),
    ranks,
    @rank_groups.build_order_index(output),
    edge_in,
    edge_out,
    order_edge_tail,
    order_edge_head,
    [0.0, 0.0],
    [0.0, 0.0],
    [1, 1],
  )

  assert_eq(before_crossings, 1)
  assert_eq(after_crossings, 0)
}
