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

  assert_eq(
    count_crossings(
      groups,
      ranks,
      edges,
      edge_tail,
      edge_head,
    ),
    1,
  )
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
