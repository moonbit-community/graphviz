///|
test "median_value sorts inputs and averages the middle pair" {
  assert_eq(median_value([]), None)
  assert_eq(median_value([3.0, 1.0, 2.0]), Some(2.0))
  assert_eq(median_value([4.0, 1.0, 3.0, 2.0]), Some(2.5))
}

///|
test "median_value_mc_scale follows Graphviz integer scaling" {
  assert_eq(median_value_mc_scale([0.0, 1.0]), Some(0.5))
  assert_eq(median_value_mc_scale([0.1, 0.2, 0.3]), Some(0.19921875))
  assert_eq(median_value_mc_scale([0.0, 1.0, 3.0, 10.0]), Some(1.25))
}

///|
test "collect_rank_keys returns sorted ranks" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[3] = ["c"]
  groups[1] = ["a"]
  groups[2] = ["b"]

  assert_eq(collect_rank_keys(groups), [1, 2, 3])
}

///|
test "build_node_ranks and build_order_index flatten rank groups consistently" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[2] = ["c", "d"]
  groups[0] = ["a"]
  groups[1] = ["b"]

  let ranks = build_node_ranks(groups)
  let order = build_order_index(groups)

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
  assert_eq(ranks.get("c"), Some(2))
  assert_eq(ranks.get("d"), Some(2))

  assert_eq(order.get("a"), Some(0))
  assert_eq(order.get("b"), Some(0))
  assert_eq(order.get("c"), Some(0))
  assert_eq(order.get("d"), Some(1))
}

///|
test "count_crossings counts inversions across adjacent ranks" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["x", "y"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")
  let edges = [graph.edge(a, y), graph.edge(b, x)]
  let edge_tail = ["a", "b"]
  let edge_head = ["y", "x"]

  assert_eq(count_crossings(groups, ranks, edges, edge_tail, edge_head), 1)
}

///|
test "crossing_for_pair counts parent and child inversions" {
  let parent_orders : Map[String, Array[Int]] = Map::new()
  parent_orders["left"] = [1, 3]
  parent_orders["right"] = [0, 2]

  let child_orders : Map[String, Array[Int]] = Map::new()
  child_orders["left"] = [0, 4]
  child_orders["right"] = [1, 2]

  assert_eq(crossing_for_pair("left", "right", parent_orders, child_orders), 5)
}

///|
test "left2right_constraint combines cluster pinning and flat constraints" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["left"] = "cluster_a"
  cluster_keys["right"] = "cluster_b"
  cluster_keys["skeleton"] = "cluster_b"

  let cluster_skeleton : Map[String, Bool] = Map::new()
  cluster_skeleton["skeleton"] = true

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["flat_left|flat_right"] = true

  assert_true(
    left2right_constraint(
      "left", "right", cluster_keys, cluster_skeleton, flat_constraints,
    ),
  )
  assert_false(
    left2right_constraint(
      "left", "skeleton", cluster_keys, cluster_skeleton, flat_constraints,
    ),
  )
  assert_true(
    left2right_constraint(
      "flat_left", "flat_right", cluster_keys, cluster_skeleton, flat_constraints,
    ),
  )
  assert_true(
    left2right_constraint(
      "plain",
      "left",
      cluster_keys,
      cluster_skeleton,
      flat_constraints,
      remincross_mode=true,
    ),
  )
}

///|
test "build_vnode_extra_nodes preserves explicit vnode order before fallback entries" {
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  vnode_ranks["v2"] = 2
  vnode_ranks["v3"] = 3

  let extra = build_vnode_extra_nodes(["v2", "missing", "v1"], vnode_ranks)

  assert_eq(extra.length(), 3)
  assert_eq(extra[0].name, "v2")
  assert_eq(extra[0].rank, 2)
  assert_eq(extra[1].name, "v1")
  assert_eq(extra[1].rank, 1)
  assert_eq(extra[2].name, "v3")
  assert_eq(extra[2].rank, 3)
}

///|
test "apply_rank_same_order reorders unported rank-same groups only" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b", "c", "d"]

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

  let adjusted = apply_rank_same_order(
    groups,
    rank_same_groups,
    rank_same_order,
    Map::new(),
    port_edge_nodes,
  )

  assert_eq(adjusted.get(0), Some(["b", "a", "c", "d"]))
}

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
