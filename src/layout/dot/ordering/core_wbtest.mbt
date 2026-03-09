

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
