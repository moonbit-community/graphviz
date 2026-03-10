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
