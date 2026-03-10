///|
test "build_remincross_materialized_arrays replays materialized tail buckets in rem_nlist order" {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  rem_groups[0] = ["a"]
  rem_groups[1] = ["v1", "b"]
  let rem_nodes = @order_graph.build_order_nodes_from_groups(rem_groups, [0, 1])
  let rem_graph_output = @order_graph.build_order_graph_and_nodes(
    "rem_test", rem_nodes,
  )

  let materialized_edges : ReMincrossMaterializedOrderEdges = {
    order_edges_by_tail: {
      "a": [("a", "v1", 5, true, 1.0, 2.0, 0.1, 0.2)],
      "v1": [("v1", "b", 6, true, 3.0, 4.0, 0.3, 0.4)],
    },
    vnode_creation: { "a": ["v1"] },
    edge_creation: [("a", "v1"), ("v1", "b")],
  }

  let arrays = build_remincross_materialized_arrays(
    {
      rem_rank_keys: [0, 1],
      rem_groups,
      creation_order: ["a"],
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_tail_port_x: [],
      edge_head_port_x: [],
      edge_tail_port_order: [],
      edge_head_port_order: [],
      ranks: Map::new(),
      edge_vnodes: Map::new(),
      order_with_vnodes: true,
      intercluster_keys: Map::new(),
      cluster_order: [],
      order_with_clusters: false,
      edges_by_tail: Map::new(),
      root_tail_order_override: None,
      root_cluster: "__root__",
      cluster_parents: Map::new(),
      order_sizes: Map::new(),
      vnode_sizes: Map::new(),
      cluster_flat_constraints: Map::new(),
      rank_same_constraints: Map::new(),
    },
    rem_graph_output.order_graph,
    rem_graph_output.order_node_map,
    Map::new(),
    materialized_edges,
  )

  assert_eq(arrays.node_order.get("a"), Some(0))
  assert_eq(arrays.node_order.get("v1"), Some(0))
  assert_eq(arrays.node_order.get("b"), Some(1))
  assert_eq(arrays.edge_tail_out, ["v1", "a"])
  assert_eq(arrays.edge_head_out, ["b", "v1"])
  assert_eq(arrays.edge_tail_port_order, [0.3, 0.1])
  assert_eq(arrays.edge_head_port_order, [0.4, 0.2])
}

///|
test "build_remincross_materialized_inputs assembles rem nodes edges sizes cluster keys and flat constraints" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_ab = graph.edge(a, b)

  let rem_groups : Map[Int, Array[String]] = Map::new()
  rem_groups[0] = ["a"]
  rem_groups[1] = ["b"]
  let order_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)

  let materialized = build_remincross_materialized_inputs({
    rem_rank_keys: [0, 1],
    rem_groups,
    creation_order: ["a"],
    edges: [edge_ab],
    edge_tail: [],
    edge_head: [],
    edge_tail_port_x: [],
    edge_head_port_x: [],
    edge_tail_port_order: [],
    edge_head_port_order: [],
    ranks: { "a": 0, "b": 1 },
    edge_vnodes: Map::new(),
    order_with_vnodes: false,
    intercluster_keys: { "a": "", "b": "" },
    cluster_order: [],
    order_with_clusters: false,
    edges_by_tail: { "a": [0] },
    root_tail_order_override: None,
    root_cluster: "__root__",
    cluster_parents: Map::new(),
    order_sizes,
    vnode_sizes: Map::new(),
    cluster_flat_constraints: { "a|b": false },
    rank_same_constraints: { "b|c": false },
  })

  assert_eq(materialized.rem_nodes, ["a", "b"])
  assert_eq(materialized.rem_ranks.get("a"), Some(0))
  assert_eq(materialized.rem_ranks.get("b"), Some(1))
  assert_eq(materialized.rem_node_order.get("a"), Some(0))
  assert_eq(materialized.rem_node_order.get("b"), Some(0))
  assert_eq(materialized.rem_edge_tail_out, ["a"])
  assert_eq(materialized.rem_edge_head_out, ["b"])
  assert_eq(materialized.rem_cluster_keys.get("a"), Some("__root__"))
  assert_eq(materialized.rem_cluster_keys.get("b"), Some("__root__"))
  assert_eq(
    materialized.rem_sizes.get("a").map(fn(size) { size.width_pt }),
    Some(10.0),
  )
  assert_eq(
    materialized.rem_sizes.get("b").map(fn(size) { size.height_pt }),
    Some(9.0),
  )
  assert_eq(materialized.rem_flat_constraints.get("a|b"), Some(false))
  assert_eq(materialized.rem_flat_constraints.get("b|c"), Some(true))
}

///|
test "build_remincross_materialized_edges coalesces duplicate chains, applies vnode-tail bonus, and replays edge creation from real tails only" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  edge_1.set_attr("xpenalty", "2")
  edge_2.set_attr("xpenalty", "2")

  let shared_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}shared_0"
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_1)] = [shared_vnode]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_2)] = [shared_vnode]

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["a"] = [0, 1]

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster_left"
  intercluster_keys["b"] = "cluster_right"

  let materialized = build_remincross_materialized_edges(
    {
      rem_rank_keys: [0, 2],
      rem_groups: Map::new(),
      creation_order: ["a"],
      edges: [edge_1, edge_2],
      edge_tail: [],
      edge_head: [],
      edge_tail_port_x: [],
      edge_head_port_x: [],
      edge_tail_port_order: [],
      edge_head_port_order: [],
      ranks: { "a": 0, "b": 2 },
      edge_vnodes,
      order_with_vnodes: true,
      intercluster_keys,
      cluster_order: ["cluster_left", "cluster_right"],
      order_with_clusters: true,
      edges_by_tail,
      root_tail_order_override: None,
      root_cluster: "__root__",
      cluster_parents: Map::new(),
      order_sizes: Map::new(),
      vnode_sizes: Map::new(),
      cluster_flat_constraints: Map::new(),
      rank_same_constraints: Map::new(),
    },
    { "cluster_left": 0, "cluster_right": 1 },
  )

  assert_eq(materialized.vnode_creation.get("a"), Some([shared_vnode]))
  assert_eq(materialized.edge_creation, [("a", shared_vnode)])
  assert_eq(
    materialized.order_edges_by_tail
    .get("a")
    .map(fn(entries) { entries.map(materialized_entry_penalty) }),
    Some([4]),
  )
  assert_eq(
    materialized.order_edges_by_tail
    .get(shared_vnode)
    .map(fn(entries) { entries.map(materialized_entry_penalty) }),
    Some([5]),
  )
}

///|
test "build_remincross_materialized_edges replays edge creation in creation-order across multiple real tails" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let edge_ab = graph.edge(a, b)
  let edge_cd = graph.edge(c, d)

  let vnode_ab = "\{@edge_identity.EDGE_VNODE_PREFIX}ab_0"
  let vnode_cd = "\{@edge_identity.EDGE_VNODE_PREFIX}cd_0"
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_ab)] = [vnode_ab]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cd)] = [vnode_cd]

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["c"] = [1]
  edges_by_tail["a"] = [0]

  let materialized = build_remincross_materialized_edges(
    {
      rem_rank_keys: [0, 2],
      rem_groups: Map::new(),
      creation_order: ["c", "a"],
      edges: [edge_ab, edge_cd],
      edge_tail: [],
      edge_head: [],
      edge_tail_port_x: [],
      edge_head_port_x: [],
      edge_tail_port_order: [],
      edge_head_port_order: [],
      ranks: { "a": 0, "b": 2, "c": 0, "d": 2 },
      edge_vnodes,
      order_with_vnodes: true,
      intercluster_keys: Map::new(),
      cluster_order: [],
      order_with_clusters: false,
      edges_by_tail,
      root_tail_order_override: None,
      root_cluster: "__root__",
      cluster_parents: Map::new(),
      order_sizes: Map::new(),
      vnode_sizes: Map::new(),
      cluster_flat_constraints: Map::new(),
      rank_same_constraints: Map::new(),
    },
    Map::new(),
  )

  assert_eq(materialized.vnode_creation.get("c"), Some([vnode_cd]))
  assert_eq(materialized.vnode_creation.get("a"), Some([vnode_ab]))
  assert_eq(materialized.edge_creation, [("c", vnode_cd), ("a", vnode_ab)])
}

///|
test "build_remincross_materialized_inputs keeps clustered vnode sizes and root-cluster vnode keys" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_ab = graph.edge(a, b)

  let shared_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}shared_clustered_0"
  let rem_groups : Map[Int, Array[String]] = Map::new()
  rem_groups[0] = ["a"]
  rem_groups[1] = [shared_vnode]
  rem_groups[2] = ["b"]

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_ab)] = [shared_vnode]

  let order_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes[shared_vnode] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 6.0,
  )

  let materialized = build_remincross_materialized_inputs({
    rem_rank_keys: [0, 1, 2],
    rem_groups,
    creation_order: ["a"],
    edges: [edge_ab],
    edge_tail: [],
    edge_head: [],
    edge_tail_port_x: [],
    edge_head_port_x: [],
    edge_tail_port_order: [],
    edge_head_port_order: [],
    ranks: { "a": 0, "b": 2 },
    edge_vnodes,
    order_with_vnodes: true,
    intercluster_keys: { "a": "cluster_left", "b": "cluster_right" },
    cluster_order: ["cluster_left", "cluster_mid", "cluster_right"],
    order_with_clusters: true,
    edges_by_tail: { "a": [0] },
    root_tail_order_override: None,
    root_cluster: "__root__",
    cluster_parents: Map::new(),
    order_sizes,
    vnode_sizes,
    cluster_flat_constraints: { "a|b": false },
    rank_same_constraints: { "b|c": false },
  })

  assert_eq(materialized.rem_cluster_keys.get("a"), Some("cluster_left"))
  assert_eq(materialized.rem_cluster_keys.get("b"), Some("cluster_right"))
  assert_eq(materialized.rem_cluster_keys.get(shared_vnode), Some("__root__"))
  assert_eq(materialized.rem_edge_tail_out, ["a", shared_vnode])
  assert_eq(materialized.rem_edge_head_out, [shared_vnode, "b"])
  assert_eq(
    materialized.rem_sizes.get(shared_vnode).map(fn(size) { size.width_pt }),
    Some(5.0),
  )
  assert_eq(
    materialized.rem_sizes.get(shared_vnode).map(fn(size) { size.height_pt }),
    Some(6.0),
  )
  assert_eq(materialized.rem_flat_constraints.length(), 0)
}
