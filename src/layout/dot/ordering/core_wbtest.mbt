

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
