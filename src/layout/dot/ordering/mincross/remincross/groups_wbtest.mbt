///|
test "build_remincross_groups prefers seeded vnode-inclusive replay for single-cluster cleanup" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_only", 0)

  let final_groups : Map[Int, Array[String]] = Map::new()
  final_groups[0] = ["a", "b"]

  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_with_vnodes[0] = [skeleton, "v_before", "a", "b"]

  let rem_groups = build_remincross_groups({
    ratio: "",
    cluster_order: ["cluster_only"],
    ordered_with_vnodes,
    cluster_keys: Map::new(),
    vnode_group_inputs: {
      final_groups,
      order_with_vnodes: true,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      cluster_min_rank: Map::new(),
      cluster_max_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
    },
  })

  assert_eq(rem_groups.get(0), Some(["v_before", "a", "b"]))
}

///|
test "build_remincross_groups falls back to vnode-group rebuild when seeded replay is empty under ratio fill" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_only", 0)

  let final_groups : Map[Int, Array[String]] = Map::new()
  final_groups[0] = ["a"]
  final_groups[1] = ["b"]

  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_with_vnodes[0] = [skeleton]

  let rem_groups = build_remincross_groups({
    ratio: "fill",
    cluster_order: ["cluster_a", "cluster_b"],
    ordered_with_vnodes,
    cluster_keys: Map::new(),
    vnode_group_inputs: {
      final_groups,
      order_with_vnodes: true,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      cluster_min_rank: Map::new(),
      cluster_max_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
    },
  })

  assert_eq(rem_groups.get(0), Some(["a"]))
  assert_eq(rem_groups.get(1), Some(["b"]))
}
