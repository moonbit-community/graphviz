///|
fn new_test_graph(
  names : Array[String],
) -> (@cgraph.Graph, Map[String, @cgraph.Node]) {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node_map : Map[String, @cgraph.Node] = Map::new()
  for name in names {
    node_map[name] = graph.node(name)
  }
  (graph, node_map)
}

///|
fn sample_node_size(
  width_pt : Double,
  height_pt : Double,
) -> @node_primitives.NodeSize {
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

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
test "build_xpos_chain_with_vnodes respects rank direction" {
  let forward_ranks : Map[String, Int] = { "tail": 0, "head": 3 }
  let reverse_ranks : Map[String, Int] = { "tail": 3, "head": 0 }

  assert_eq(
    build_xpos_chain_with_vnodes(forward_ranks, "tail", "head", ["v1", "v2"]),
    ["tail", "v1", "v2", "head"],
  )
  assert_eq(
    build_xpos_chain_with_vnodes(reverse_ranks, "tail", "head", ["v1", "v2"]),
    ["tail", "v2", "v1", "head"],
  )
}

///|
test "append_xpos_edge_with_vnodes keeps endpoint port hints on outer segments only" {
  let (graph, order_node_map) = new_test_graph(["a", "v1", "v2", "b"])
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  let ranks : Map[String, Int] = { "a": 0, "v1": 1, "v2": 2, "b": 3 }

  append_xpos_edge_with_vnodes(
    graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    ranks,
    "a",
    "b",
    7,
    true,
    1.0,
    3.0,
    0.2,
    0.8,
    ["v1", "v2"],
  )

  assert_eq(order_edge_tail_out, ["a", "v1", "v2"])
  assert_eq(order_edge_head_out, ["v1", "v2", "b"])
  assert_eq(order_edge_tail_port_x, [1.0, 0.0, 0.0])
  assert_eq(order_edge_head_port_x, [0.0, 0.0, 3.0])
  assert_eq(order_edge_tail_port_order, [0.2, 0.5, 0.5])
  assert_eq(order_edge_head_port_order, [0.5, 0.5, 0.8])
  assert_eq(order_edges_out.length(), 3)
}

///|
test "build_clustered_xpos_seed injects skeleton nodes without mutating source groups" {
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a"]
  x_groups[2] = ["b"]

  let x_order_sizes : Map[String, @node_primitives.NodeSize] = {
    "a": sample_node_size(10.0, 8.0),
    "b": sample_node_size(12.0, 6.0),
  }
  let x_cluster_keys : Map[String, String] = { "a": "cluster_0" }
  let cluster_min_rank : Map[String, Int] = { "cluster_0": 0 }
  let cluster_max_rank : Map[String, Int] = { "cluster_0": 1 }
  let node_order : Map[String, Int] = { "a": 5 }
  let cluster_skeleton_size = sample_node_size(4.0, 4.0)
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_0", 0)
  let skeleton_1 = @cluster_identity.cluster_skeleton_name("cluster_0", 1)

  let seed = build_clustered_xpos_seed({
    x_groups,
    x_order_sizes,
    x_cluster_keys,
    cluster_min_rank,
    cluster_max_rank,
    node_order,
    cluster_skeleton_size,
  })

  assert_eq(x_groups.get(0), Some(["a"]))
  assert_eq(seed.order_groups.get(0), Some(["a", skeleton_0]))
  assert_eq(seed.order_groups.get(1), Some([skeleton_1]))
  assert_eq(seed.order_groups.get(2), Some(["b"]))
  assert_eq(
    seed.order_sizes.get(skeleton_0).map(fn(size) { size.width_pt }),
    Some(4.0),
  )
  assert_eq(
    seed.order_sizes.get(skeleton_0).map(fn(size) { size.height_pt }),
    Some(4.0),
  )
  assert_eq(seed.order_cluster_keys.get(skeleton_1), Some("cluster_0"))
  assert_eq(seed.order_cluster_skeleton.get(skeleton_0), Some(true))
  assert_eq(seed.order_node_order.get("a"), Some(5))
  assert_eq(seed.order_node_order.get(skeleton_0), Some(1))
  assert_eq(seed.order_node_order.get(skeleton_1), Some(0))
  assert_eq(seed.order_rank_keys, [0, 1, 2])
  assert_eq(seed.order_ranks.get(skeleton_1), Some(1))
  assert_eq(seed.order_nodes, ["a", skeleton_0, skeleton_1, "b"])
}

///|
test "build_clustered_xpos_edges expands vnode chains and appends skeleton links" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("xpenalty", "9")

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1"]

  let ranks : Map[String, Int] = { "a": 0, "v1": 1, "b": 2 }
  let cluster_min_rank : Map[String, Int] = { "cluster_0": 0 }
  let cluster_max_rank : Map[String, Int] = { "cluster_0": 1 }
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_0", 0)
  let skeleton_1 = @cluster_identity.cluster_skeleton_name("cluster_0", 1)

  let output = build_clustered_xpos_edges({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    ranks,
    edge_vnodes,
    order_nodes: ["a", "v1", "b", skeleton_0, skeleton_1],
    edge_tail_port_x: [1.0],
    edge_head_port_x: [2.0],
    edge_tail_port_order: [0.1],
    edge_head_port_order: [0.9],
    cluster_min_rank,
    cluster_max_rank,
    cluster_skeleton_penalty: 11,
  })

  assert_eq(output.order_edge_tail_out, ["a", "v1", skeleton_0])
  assert_eq(output.order_edge_head_out, ["v1", "b", skeleton_1])
  assert_eq(output.order_edge_tail_port_x, [1.0, 0.0, 0.0])
  assert_eq(output.order_edge_head_port_x, [0.0, 2.0, 0.0])
  assert_eq(output.order_edge_tail_port_order, [0.1, 0.5, 0.5])
  assert_eq(output.order_edge_head_port_order, [0.5, 0.9, 0.5])
  assert_eq(output.order_edges_out.length(), 3)
  assert_eq(output.order_edges_out[0].get_attr("xpenalty"), Some("9"))
  assert_eq(output.order_edges_out[2].get_attr("xpenalty"), Some("11"))
}

///|
test "build_clustered_xpos_edges uses remapped endpoint snapshots and defaults missing port hints" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("xpenalty", "13")

  let output = build_clustered_xpos_edges({
    edges: [edge],
    edge_tail: ["tail_override"],
    edge_head: ["head_override"],
    ranks: { "tail_override": 0, "head_override": 1 },
    edge_vnodes: Map::new(),
    order_nodes: ["tail_override", "head_override"],
    edge_tail_port_x: [],
    edge_head_port_x: [],
    edge_tail_port_order: [],
    edge_head_port_order: [],
    cluster_min_rank: Map::new(),
    cluster_max_rank: Map::new(),
    cluster_skeleton_penalty: 11,
  })

  assert_eq(output.order_edge_tail_out, ["tail_override"])
  assert_eq(output.order_edge_head_out, ["head_override"])
  assert_eq(output.order_edge_tail_port_x, [0.0])
  assert_eq(output.order_edge_head_port_x, [0.0])
  assert_eq(output.order_edge_tail_port_order, [0.5])
  assert_eq(output.order_edge_head_port_order, [0.5])
  assert_eq(output.order_edges_out.length(), 1)
  assert_eq(output.order_edges_out[0].get_attr("xpenalty"), Some("13"))
}

///|
test "append_clustered_input_edges mixes direct edges, reverse vnode chains, and partial snapshot fallback" {
  let source_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let direct_tail = source_graph.node("direct_tail")
  let direct_head = source_graph.node("direct_head")
  let down_tail = source_graph.node("down_tail")
  let down_head = source_graph.node("down_head")
  let direct_edge = source_graph.edge(direct_tail, direct_head)
  let down_edge = source_graph.edge(down_tail, down_head)
  direct_edge.set_attr("xpenalty", "5")
  down_edge.set_attr("xpenalty", "7")

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(down_edge)] = ["down_v1", "down_v2"]

  let input : ClusteredXposEdgeMaterializationInput = {
    edges: [direct_edge, down_edge],
    edge_tail: ["mapped_tail"],
    edge_head: ["mapped_head"],
    ranks: {
      "mapped_tail": 0,
      "mapped_head": 1,
      "down_tail": 3,
      "down_v1": 1,
      "down_v2": 2,
      "down_head": 0,
    },
    edge_vnodes,
    order_nodes: [
      "mapped_tail", "mapped_head", "down_tail", "down_v1", "down_v2", "down_head",
    ],
    edge_tail_port_x: [1.25],
    edge_head_port_x: [],
    edge_tail_port_order: [0.2],
    edge_head_port_order: [0.8, 0.9],
    cluster_min_rank: Map::new(),
    cluster_max_rank: Map::new(),
    cluster_skeleton_penalty: 11,
  }

  let (order_graph, order_node_map) = new_test_graph(input.order_nodes)
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []

  append_clustered_input_edges(
    input, order_graph, order_node_map, order_edges_out, order_edge_tail_out, order_edge_head_out,
    order_edge_tail_port_x, order_edge_head_port_x, order_edge_tail_port_order, order_edge_head_port_order,
  )

  assert_eq(order_edge_tail_out, [
    "mapped_tail", "down_tail", "down_v2", "down_v1",
  ])
  assert_eq(order_edge_head_out, [
    "mapped_head", "down_v2", "down_v1", "down_head",
  ])
  assert_eq(order_edge_tail_port_x, [1.25, 0.0, 0.0, 0.0])
  assert_eq(order_edge_head_port_x, [0.0, 0.0, 0.0, 0.0])
  assert_eq(order_edge_tail_port_order, [0.2, 0.5, 0.5, 0.5])
  assert_eq(order_edge_head_port_order, [0.8, 0.5, 0.5, 0.9])
  assert_eq(order_edges_out.length(), 4)
  assert_eq(order_edges_out[0].get_attr("xpenalty"), Some("5"))
  assert_eq(order_edges_out[1].get_attr("xpenalty"), Some("7"))
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
