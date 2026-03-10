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
test "compute_desired_positions prefers explicit positions, then port anchors, then neighbor medians" {
  let neighbors : Map[String, Array[String]] = Map::new()
  neighbors["median"] = ["n1", "n2", "n3"]
  neighbors["fallback"] = ["n2", "n3"]

  let x_positions : Map[String, Double] = Map::new()
  x_positions["anchor_left"] = 10.0
  x_positions["anchor_right"] = 30.0
  x_positions["n1"] = 2.0
  x_positions["n2"] = 6.0
  x_positions["n3"] = 100.0

  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  port_order_contrib["preferred"] = [("anchor_left", 99.0)]
  port_order_contrib["ported"] = [
    ("anchor_left", 1.5),
    ("anchor_right", -0.5),
    ("missing_anchor", 5.0),
  ]
  port_order_contrib["fallback"] = [("missing_anchor", 8.0)]

  let preferred_positions : Map[String, Double] = Map::new()
  preferred_positions["preferred"] = 42.0

  let desired = compute_desired_positions(
    ["preferred", "ported", "median", "fallback", "missing"],
    neighbors,
    x_positions,
    port_order_contrib,
    preferred_positions,
  )

  assert_eq(desired.get("preferred"), Some(42.0))
  assert_eq(desired.get("ported"), Some(20.5))
  assert_eq(desired.get("median"), Some(6.0))
  assert_eq(desired.get("fallback"), Some(53.0))
  assert_eq(desired.get("missing"), None)
}

///|
test "compute_scaled_medians applies port offsets before Graphviz scaling" {
  let neighbors : Map[String, Array[(String, Double)]] = Map::new()
  neighbors["ported"] = [("left", 0.1), ("right", 0.0), ("missing", 8.0)]

  let x_positions : Map[String, Double] = Map::new()
  x_positions["left"] = 0.0
  x_positions["right"] = 1.0

  let desired = compute_scaled_medians(["ported"], neighbors, x_positions)

  assert_eq(desired.get("ported"), Some(0.546875))
}

///|
test "reorder_by_medians keeps left-to-right constrained pairs pinned" {
  let desired : Map[String, Double] = Map::new()
  desired["a"] = 2.0
  desired["b"] = 1.0
  desired["c"] = 0.0

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|b"] = true

  let reordered = reorder_by_medians(
    ["a", "b", "c"],
    desired,
    false,
    false,
    Map::new(),
    Map::new(),
    flat_constraints,
  )

  assert_eq(reordered, ["c", "a", "b"])
}

///|
test "count_rank_crossings_port uses port x offsets to break equal-order ties" {
  let ranks : Map[String, Int] = Map::new()
  ranks["p"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let fixed_order : Map[String, Int] = Map::new()

  let edge_in : Map[String, Array[Int]] = Map::new()
  edge_in["x"] = [0]
  edge_in["y"] = [1]

  let edge_out : Map[String, Array[Int]] = Map::new()

  let crossings = count_rank_crossings_port(
    1,
    ["x", "y"],
    ranks,
    fixed_order,
    edge_in,
    edge_out,
    ["p", "p"],
    ["x", "y"],
    [2.0, 1.0],
    [],
    [1, 1],
  )

  assert_eq(crossings, 1)
}

///|
test "flat_reorder_rank_groups topologically reorders constrained ranks" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b", "c", "d"]

  let node_ranks : Map[String, Int] = Map::new()
  node_ranks["a"] = 0
  node_ranks["b"] = 0
  node_ranks["c"] = 0
  node_ranks["d"] = 0

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|c"] = true
  flat_constraints["c|b"] = true

  let ordered = flat_reorder_rank_groups(
    [0],
    groups,
    node_ranks,
    flat_constraints,
    false,
  )

  assert_eq(ordered.get(0), Some(["a", "c", "b", "d"]))
}
