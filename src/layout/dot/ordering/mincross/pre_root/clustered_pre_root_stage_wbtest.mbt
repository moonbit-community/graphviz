///|
test "apply_rank_same_order_nodes rewrites node order for unported groups only" {
  let node_order : Map[String, Int] = Map::new()
  node_order["a"] = 2
  node_order["b"] = 5
  node_order["c"] = 9
  node_order["d"] = 7

  let rank_same_groups : Map[String, Int] = Map::new()
  rank_same_groups["a"] = 1
  rank_same_groups["b"] = 1
  rank_same_groups["c"] = 2
  rank_same_groups["d"] = 2

  let rank_same_order : Map[String, Int] = Map::new()
  rank_same_order["b"] = 0
  rank_same_order["a"] = 1
  rank_same_order["d"] = 0
  rank_same_order["c"] = 1

  let port_edge_nodes : Map[String, Bool] = Map::new()
  port_edge_nodes["c"] = true

  apply_rank_same_order_nodes(
    node_order, rank_same_groups, rank_same_order, port_edge_nodes,
  )

  assert_eq(node_order.get("b"), Some(2))
  assert_eq(node_order.get("a"), Some(5))
  assert_eq(node_order.get("c"), Some(9))
  assert_eq(node_order.get("d"), Some(7))
}

///|
test "build_order_seed_groups merges vnode groups and appends cluster skeletons in cluster order before unseen clusters" {
  let ordering_groups_base : Map[Int, Array[String]] = Map::new()
  ordering_groups_base[0] = ["a"]
  ordering_groups_base[1] = ["b"]

  let base_order_index : Map[String, Int] = Map::new()
  base_order_index["a"] = 0
  base_order_index["b"] = 0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_x"
  cluster_keys["b"] = "cluster_y"

  let cluster_min_rank : Map[String, Int] = Map::new()
  cluster_min_rank["cluster_y"] = 1
  cluster_min_rank["cluster_x"] = 0
  cluster_min_rank["cluster_z"] = 1

  let cluster_max_rank : Map[String, Int] = Map::new()
  cluster_max_rank["cluster_x"] = 1
  cluster_max_rank["cluster_z"] = 1

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v0"] = "cluster_x"

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v0"]

  let vnode_order_keys_for_ordering : Map[String, Double] = Map::new()
  vnode_order_keys_for_ordering["v0"] = 0.5

  let order_sizes : Map[String, NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)

  let vnode_sizes : Map[String, NodeSize] = Map::new()
  vnode_sizes["v0"] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 4.0,
  )

  let skeleton_size = @node_primitives.node_size_from_points(6.0, 6.0)

  let seeded = build_order_seed_groups({
    ordering_groups_base,
    base_order_index,
    order_with_vnodes: true,
    order_with_clusters: true,
    cluster_keys,
    cluster_order: ["cluster_y", "cluster_x"],
    cluster_min_rank,
    cluster_max_rank,
    vnode_clusters,
    vnodes_by_rank,
    vnode_order_keys_for_ordering,
    order_sizes,
    vnode_sizes,
    skeleton_size,
  })

  let skel_x_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)
  let skel_x_1 = @cluster_identity.cluster_skeleton_name("cluster_x", 1)
  let skel_y_1 = @cluster_identity.cluster_skeleton_name("cluster_y", 1)
  let skel_z_1 = @cluster_identity.cluster_skeleton_name("cluster_z", 1)

  assert_eq(seeded.order_groups.get(0), Some(["a", "v0", skel_x_0]))
  assert_eq(
    seeded.order_groups.get(1),
    Some(["b", skel_y_1, skel_x_1, skel_z_1]),
  )
  assert_eq(seeded.order_cluster_keys.get("a"), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get("b"), Some("cluster_y"))
  assert_eq(seeded.order_cluster_keys.get("v0"), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get(skel_x_0), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get(skel_y_1), Some("cluster_y"))
  assert_eq(seeded.order_cluster_keys.get(skel_z_1), Some("cluster_z"))
  assert_eq(seeded.order_cluster_skeleton.get(skel_x_0), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_x_1), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_y_1), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_z_1), Some(true))
  assert_eq(
    seeded.order_sizes_out.get("v0").map(fn(size) { size.width_pt }),
    Some(5.0),
  )
  assert_eq(
    seeded.order_sizes_out.get(skel_x_0).map(fn(size) { size.height_pt }),
    Some(6.0),
  )
}

///|
test "build_order_seed_groups keeps only real-node metadata when vnode and cluster ordering are disabled" {
  let ordering_groups_base : Map[Int, Array[String]] = Map::new()
  ordering_groups_base[0] = ["a", "b"]

  let order_sizes : Map[String, NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)

  let seeded = build_order_seed_groups({
    ordering_groups_base,
    base_order_index: Map::new(),
    order_with_vnodes: false,
    order_with_clusters: false,
    cluster_keys: { "a": "cluster_a" },
    cluster_order: ["cluster_a"],
    cluster_min_rank: { "cluster_a": 0 },
    cluster_max_rank: { "cluster_a": 0 },
    vnode_clusters: { "v0": "cluster_a" },
    vnodes_by_rank: { 0: ["v0"] },
    vnode_order_keys_for_ordering: { "v0": 0.5 },
    order_sizes,
    vnode_sizes: {
      "v0": @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 4.0),
    },
    skeleton_size: @node_primitives.node_size_from_points(6.0, 6.0),
  })

  match seeded.order_groups.get(0) {
    Some(list) => list[0] = "mutated"
    None => fail("missing seeded rank")
  }

  assert_eq(ordering_groups_base.get(0), Some(["a", "b"]))
  assert_eq(seeded.order_groups.get(0), Some(["mutated", "b"]))
  assert_eq(seeded.order_cluster_keys, { "a": "cluster_a" })
  assert_eq(seeded.order_cluster_skeleton.length(), 0)
  assert_true(seeded.order_sizes_out.get("v0") is None)
  assert_eq(
    seeded.order_sizes_out.get("a").map(fn(size) { size.width_pt }),
    Some(10.0),
  )
}

///|
test "build_order_reorder_context assembles rank keys graphs creation order and node-order fallbacks on noncluster path" {
  let order_groups : Map[Int, Array[String]] = Map::new()
  order_groups[0] = ["a", "b", "v0"]
  order_groups[1] = ["d"]

  let context = build_order_reorder_context({
    order_groups,
    nlist_order: ["a", "v0"],
    gdnlist_order: ["a", "b"],
    node_order: { "c": 7 },
    real_nodes: {
      "a": true,
      "b": true,
      "c": true,
      "d": true,
      "extra_real": true,
    },
    has_clusters: false,
    base_order_index: { "extra_real": 11, "a": 99 },
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: Map::new(),
  })

  assert_eq(context.order_rank_keys, [0, 1])
  assert_eq(context.order_ranks.get("a"), Some(0))
  assert_eq(context.order_ranks.get("b"), Some(0))
  assert_eq(context.order_ranks.get("v0"), Some(0))
  assert_eq(context.order_ranks.get("d"), Some(1))
  assert_eq(context.order_nodes, ["a", "b", "v0", "d"])
  assert_eq(context.creation_order, ["v0", "a"])
  assert_true(context.order_node_map.get("a") is Some(_))
  assert_true(context.order_node_map_unmapped.get("d") is Some(_))
  assert_true(context.order_node_map.get("extra_real") is None)
  assert_eq(context.order_node_order.get("a"), Some(0))
  assert_eq(context.order_node_order.get("b"), Some(1))
  assert_eq(context.order_node_order.get("v0"), Some(2))
  assert_eq(context.order_node_order.get("c"), Some(7))
  assert_eq(context.order_node_order.get("d"), Some(0))
  assert_eq(context.order_node_order.get("extra_real"), Some(11))
}

///|
test "build_order_reorder_context applies rank-same normalization only when clusters are enabled" {
  let order_groups : Map[Int, Array[String]] = Map::new()
  order_groups[0] = ["a", "b"]
  let empty_nlist : Array[String] = []
  let empty_node_order : Map[String, Int] = Map::new()
  let empty_base_order_index : Map[String, Int] = Map::new()
  let empty_port_edge_nodes : Map[String, Bool] = Map::new()

  let nonclustered = build_order_reorder_context({
    order_groups,
    nlist_order: empty_nlist,
    gdnlist_order: ["a", "b"],
    node_order: empty_node_order,
    real_nodes: { "a": true, "b": true },
    has_clusters: false,
    base_order_index: empty_base_order_index,
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: empty_port_edge_nodes,
  })
  let clustered = build_order_reorder_context({
    order_groups,
    nlist_order: empty_nlist,
    gdnlist_order: ["a", "b"],
    node_order: empty_node_order,
    real_nodes: { "a": true, "b": true },
    has_clusters: true,
    base_order_index: empty_base_order_index,
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: empty_port_edge_nodes,
  })

  assert_eq(nonclustered.order_node_order.get("a"), Some(0))
  assert_eq(nonclustered.order_node_order.get("b"), Some(1))
  assert_eq(clustered.order_node_order.get("b"), Some(0))
  assert_eq(clustered.order_node_order.get("a"), Some(1))
}

///|
test "build_materialized_graphviz_neighbors preserves per-tail head order and AGSEQ-style incoming order" {
  let order_nodes = ["a", "b", "c", "isolated"]
  let order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail["a"] = [
    ("a", "c", 1, true, 0.0, 0.0, 0.0, 0.0),
    ("a", "b", 2, true, 0.0, 0.0, 0.0, 0.0),
  ]
  order_edges_by_tail["b"] = [("b", "c", 3, true, 0.0, 0.0, 0.0, 0.0)]

  let neighbors = build_materialized_graphviz_neighbors(
    order_nodes,
    order_edges_by_tail,
    [("b", "c"), ("a", "c"), ("a", "b")],
  )

  assert_eq(neighbors.out_neighbors.get("a"), Some(["c", "b"]))
  assert_eq(neighbors.out_neighbors.get("b"), Some(["c"]))
  assert_eq(neighbors.out_neighbors.get("c"), Some([]))
  assert_eq(neighbors.out_neighbors.get("isolated"), Some([]))
  assert_eq(neighbors.in_neighbors.get("a"), Some([]))
  assert_eq(neighbors.in_neighbors.get("b"), Some(["a"]))
  assert_eq(neighbors.in_neighbors.get("c"), Some(["b", "a"]))
  assert_eq(neighbors.in_neighbors.get("isolated"), Some([]))
}

///|
test "build_order_materialization_data replays mapped and unmapped tails in nlist order and copies flat constraints" {
  let order_nodes = ["a", "b", "c"]
  let mapped_graph_output = @order_graph.build_order_graph_and_nodes(
    "mapped_test", order_nodes,
  )
  let unmapped_graph_output = @order_graph.build_order_graph_and_nodes(
    "unmapped_test", order_nodes,
  )

  let order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail["a"] = [
    ("a", "b", 5, true, 1.0, 2.0, 0.1, 0.2),
    ("a", "c", 6, false, 3.0, 4.0, 0.3, 0.4),
  ]
  order_edges_by_tail["b"] = [("b", "c", 7, true, 5.0, 6.0, 0.5, 0.6)]

  let order_edges_by_tail_unmapped : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail_unmapped["a"] = [("a", "c", 9, true, 7.0, 8.0, 0.7, 0.8)]
  order_edges_by_tail_unmapped["b"] = [
    ("b", "a", 10, false, 9.0, 10.0, 0.9, 1.0),
  ]

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|b"] = true

  let materialized = build_order_materialization_data({
    nlist_order: ["b", "missing", "a"],
    order_edges_by_tail,
    order_graph: mapped_graph_output.order_graph,
    order_node_map: mapped_graph_output.order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped: unmapped_graph_output.order_graph,
    order_node_map_unmapped: unmapped_graph_output.order_node_map,
    order_nodes,
    edge_creation_order: [("a", "c"), ("b", "c"), ("a", "b")],
    flat_constraints,
  })

  flat_constraints["b|c"] = false

  assert_eq(materialized.order_edges_out.length(), 3)
  assert_eq(materialized.order_edge_tail_out, ["b", "a", "a"])
  assert_eq(materialized.order_edge_head_out, ["c", "b", "c"])
  assert_eq(materialized.order_edge_tail_port_x, [5.0, 1.0, 3.0])
  assert_eq(materialized.order_edge_head_port_x, [6.0, 2.0, 4.0])
  assert_eq(materialized.order_edge_tail_port_order, [0.5, 0.1, 0.3])
  assert_eq(materialized.order_edge_head_port_order, [0.6, 0.2, 0.4])
  assert_eq(materialized.order_edges_out_unmapped.length(), 2)
  assert_eq(materialized.order_edge_tail_out_unmapped, ["b", "a"])
  assert_eq(materialized.order_edge_head_out_unmapped, ["a", "c"])
  assert_eq(materialized.order_edge_tail_port_x_unmapped, [9.0, 7.0])
  assert_eq(materialized.order_edge_head_port_x_unmapped, [10.0, 8.0])
  assert_eq(materialized.order_edge_tail_port_order_unmapped, [0.9, 0.7])
  assert_eq(materialized.order_edge_head_port_order_unmapped, [1.0, 0.8])
  assert_eq(materialized.graphviz_out_neighbors.get("a"), Some(["b", "c"]))
  assert_eq(materialized.graphviz_out_neighbors.get("b"), Some(["c"]))
  assert_eq(materialized.graphviz_out_neighbors.get("c"), Some([]))
  assert_eq(materialized.graphviz_in_neighbors.get("a"), Some([]))
  assert_eq(materialized.graphviz_in_neighbors.get("b"), Some(["a"]))
  assert_eq(materialized.graphviz_in_neighbors.get("c"), Some(["a", "b"]))
  assert_eq(materialized.order_flat_constraints, { "a|b": true })
}

///|
test "apply_unconstrained_order_overrides resets isolated real nodes to gdnlist order while leaving constrained and rank-same nodes untouched" {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["connected"] = ["sink"]

  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["connected"] = 90
  order_node_order["isolated_b"] = 91
  order_node_order["isolated_a"] = 92
  order_node_order["rank_locked"] = 93

  let nodes : Array[@cgraph.Node] = []

  apply_unconstrained_order_overrides(
    ["connected", "isolated_b", "isolated_a", "rank_locked"],
    {
      "connected": true,
      "isolated_b": true,
      "isolated_a": true,
      "rank_locked": true,
    },
    ["connected", "isolated_b", "isolated_a", "rank_locked"],
    graphviz_out_neighbors,
    Map::new(),
    { "rank_locked": 1 },
    [],
    [],
    nodes,
    Map::new(),
    order_node_order,
  )

  assert_eq(order_node_order.get("connected"), Some(90))
  assert_eq(order_node_order.get("isolated_b"), Some(1))
  assert_eq(order_node_order.get("isolated_a"), Some(2))
  assert_eq(order_node_order.get("rank_locked"), Some(93))
}

///|
test "apply_unconstrained_order_overrides reassigns incoming-only local cluster nodes by first incoming edge order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let local_a = graph.node("local_a")
  let local_b = graph.node("local_b")

  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["local_a"] = []
  graphviz_out_neighbors["local_b"] = []

  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_in_neighbors["local_a"] = []
  graphviz_in_neighbors["local_b"] = []

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["local_a"] = "cluster_local"
  intercluster_keys["local_b"] = "cluster_local"

  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["local_a"] = 10
  order_node_order["local_b"] = 20

  apply_unconstrained_order_overrides(
    [],
    Map::new(),
    ["local_a", "local_b"],
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    Map::new(),
    ["tail_to_b", "tail_to_a"],
    ["local_b", "local_a"],
    [local_a, local_b],
    intercluster_keys,
    order_node_order,
  )

  assert_eq(order_node_order.get("local_b"), Some(10))
  assert_eq(order_node_order.get("local_a"), Some(20))
}
