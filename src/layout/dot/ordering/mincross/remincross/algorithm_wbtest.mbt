///|
test "collect_real_only_rank_groups drops non-real nodes and omits empty ranks" {
  let ordered : Map[Int, Array[String]] = Map::new()
  ordered[0] = ["a", "ghost"]
  ordered[1] = ["ghost_only"]
  ordered[2] = ["b", "c"]

  let real_nodes : Map[String, Bool] = Map::new()
  real_nodes["a"] = true
  real_nodes["c"] = true

  let cleaned = collect_real_only_rank_groups([0, 1, 2], ordered, real_nodes)

  assert_eq(cleaned.get(0), Some(["a"]))
  assert_eq(cleaned.get(1), None)
  assert_eq(cleaned.get(2), Some(["c"]))
}

///|
test "reorder_rank_group_by_cluster_order keeps original order when root nodes straddle clustered block" {
  let names = ["root_left", "cluster_b", "cluster_a", "root_right"]
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_a"] = "a"
  cluster_keys["cluster_b"] = "b"

  let order_map : Map[String, Int] = Map::new()
  order_map["a"] = 0
  order_map["b"] = 1

  let reordered = reorder_rank_group_by_cluster_order(
    names,
    Some(order_map),
    cluster_keys,
  )

  assert_eq(reordered, names)
}

///|
test "reorder_groups_by_local_cluster reorders within one outer cluster and keeps other slots fixed" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["root", "b", "a", "tail"]

  let outer_cluster_keys : Map[String, String] = Map::new()
  outer_cluster_keys["a"] = "outer"
  outer_cluster_keys["b"] = "outer"

  let local_cluster_keys : Map[String, String] = Map::new()
  local_cluster_keys["a"] = "local_a"
  local_cluster_keys["b"] = "local_b"

  let local_cluster_order : Map[String, Int] = Map::new()
  local_cluster_order["local_a"] = 0
  local_cluster_order["local_b"] = 1

  reorder_groups_by_local_cluster(
    groups, outer_cluster_keys, local_cluster_keys, local_cluster_order,
  )

  assert_eq(groups.get(0), Some(["root", "a", "b", "tail"]))
}

///|
test "should_skip_cluster_rank_bucket_reorder only allows single-cluster one-node-per-rank layouts" {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let only_cluster : Map[String, Int] = Map::new()
  only_cluster["cluster0"] = 0
  cluster_rank_order[0] = only_cluster
  cluster_rank_order[1] = only_cluster

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"
  cluster_keys["c"] = "cluster1"

  let one_per_rank : Map[Int, Array[String]] = Map::new()
  one_per_rank[0] = ["a", "root0"]
  one_per_rank[1] = ["root1", "b"]

  assert_true(
    should_skip_cluster_rank_bucket_reorder(
      cluster_rank_order, one_per_rank, cluster_keys,
    ),
  )

  let two_cluster_nodes_same_rank : Map[Int, Array[String]] = Map::new()
  two_cluster_nodes_same_rank[0] = ["a", "b"]
  assert_false(
    should_skip_cluster_rank_bucket_reorder(
      cluster_rank_order, two_cluster_nodes_same_rank, cluster_keys,
    ),
  )

  let multi_cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let mixed = Map::new()
  mixed["cluster0"] = 0
  mixed["cluster1"] = 1
  multi_cluster_rank_order[0] = mixed
  assert_false(
    should_skip_cluster_rank_bucket_reorder(
      multi_cluster_rank_order, one_per_rank, cluster_keys,
    ),
  )
}
