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
test "build_x_groups_with_vnodes inserts vnodes by key while preserving base order ties" {
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "b"]
  ordered_groups[1] = ["c"]

  let order_index : Map[String, Int] = Map::new()
  order_index["a"] = 0
  order_index["b"] = 1
  order_index["c"] = 0

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v2", "v1"]
  vnodes_by_rank[2] = ["v3"]

  let vnode_order_keys : Map[String, Double] = Map::new()
  vnode_order_keys["v2"] = 0.5
  vnode_order_keys["v1"] = 1.5
  vnode_order_keys["v3"] = 0.0

  let groups = build_x_groups_with_vnodes(
    ordered_groups, order_index, vnodes_by_rank, vnode_order_keys,
  )

  assert_eq(groups.get(0), Some(["a", "v2", "b", "v1"]))
  assert_eq(groups.get(1), Some(["c"]))
  assert_eq(groups.get(2), Some(["v3"]))
}

///|
test "clone_rank_groups and order_positions_from_groups keep detached local order maps" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[2] = ["c"]

  let cloned = clone_rank_groups(groups)
  match groups.get(0) {
    Some(list) => list[0] = "mutated"
    None => fail("missing original rank")
  }

  assert_eq(cloned.get(0), Some(["a", "b"]))
  let positions = order_positions_from_groups(cloned)
  assert_eq(positions.get("a"), Some(0.0))
  assert_eq(positions.get("b"), Some(1.0))
  assert_eq(positions.get("c"), Some(0.0))
}
