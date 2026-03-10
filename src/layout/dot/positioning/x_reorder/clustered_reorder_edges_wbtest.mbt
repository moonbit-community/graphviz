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
