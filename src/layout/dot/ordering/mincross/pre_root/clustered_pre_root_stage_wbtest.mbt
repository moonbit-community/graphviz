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
