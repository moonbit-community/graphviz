///|
test "build_clustered_xpos_seed injects skeleton nodes without mutating source groups" {
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a"]
  x_groups[2] = ["b"]

  let x_order_sizes : Map[String, @node_primitives.NodeSize] = {
    "a": sample_node_size(10.0, 8.0),
    "b": sample_node_size(12.0, 6.0),
  }
  let x_cluster_keys : Map[String, String] = { "a": "cluster_0" }
  let cluster_min_rank : Map[String, Int] = { "cluster_0": 0 }
  let cluster_max_rank : Map[String, Int] = { "cluster_0": 1 }
  let node_order : Map[String, Int] = { "a": 5 }
  let cluster_skeleton_size = sample_node_size(4.0, 4.0)
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_0", 0)
  let skeleton_1 = @cluster_identity.cluster_skeleton_name("cluster_0", 1)

  let seed = build_clustered_xpos_seed({
    x_groups,
    x_order_sizes,
    x_cluster_keys,
    cluster_min_rank,
    cluster_max_rank,
    node_order,
    cluster_skeleton_size,
  })

  assert_eq(x_groups.get(0), Some(["a"]))
  assert_eq(seed.order_groups.get(0), Some(["a", skeleton_0]))
  assert_eq(seed.order_groups.get(1), Some([skeleton_1]))
  assert_eq(seed.order_groups.get(2), Some(["b"]))
  assert_eq(
    seed.order_sizes.get(skeleton_0).map(fn(size) { size.width_pt }),
    Some(4.0),
  )
  assert_eq(
    seed.order_sizes.get(skeleton_0).map(fn(size) { size.height_pt }),
    Some(4.0),
  )
  assert_eq(seed.order_cluster_keys.get(skeleton_1), Some("cluster_0"))
  assert_eq(seed.order_cluster_skeleton.get(skeleton_0), Some(true))
  assert_eq(seed.order_node_order.get("a"), Some(5))
  assert_eq(seed.order_node_order.get(skeleton_0), Some(1))
  assert_eq(seed.order_node_order.get(skeleton_1), Some(0))
  assert_eq(seed.order_rank_keys, [0, 1, 2])
  assert_eq(seed.order_ranks.get(skeleton_1), Some(1))
  assert_eq(seed.order_nodes, ["a", skeleton_0, skeleton_1, "b"])
}
