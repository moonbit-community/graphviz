///|
test "build_neighbor_real_indices tracks nearest previous and next real anchors around synthetic names" {
  let indices = build_neighbor_real_indices(
    ["v_before", "a", "v_between", "c", "v_after"],
    { "a": 0, "c": 2 },
  )

  assert_eq(indices.prev_real, [None, Some(0), Some(0), Some(2), Some(2)])
  assert_eq(indices.next_real_by_pos, [Some(0), Some(0), Some(2), Some(2), None])
}

///|
test "build_seeded_rank_order uses special mixed root cluster handoff when rank starts with one vnode" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_a"] = "cluster_x"
  cluster_keys["cluster_b"] = "cluster_x"

  let ordered = build_seeded_rank_order(
    ["\{@edge_identity.EDGE_VNODE_PREFIX}0", "cluster_a", "root", "cluster_b"],
    ["cluster_a", "root", "cluster_b"],
    cluster_keys,
  )

  assert_eq(ordered, [
    "root",
    "cluster_a",
    "cluster_b",
    "\{@edge_identity.EDGE_VNODE_PREFIX}0",
  ])
}

///|
test "build_seeded_rank_order falls back to keyed merge order around nearest real nodes" {
  let ordered = build_seeded_rank_order(
    ["v_before", "a", "v_between", "c", "v_after"],
    ["a", "b", "c"],
    Map::new(),
  )

  assert_eq(ordered, ["v_before", "a", "v_between", "c", "v_after"])
}

///|
test "build_seeded_remincross drops cluster skeletons and uses base real order only when present" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_x", 0)

  let base_groups : Map[Int, Array[String]] = Map::new()
  base_groups[0] = ["a", "b"]

  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_with_vnodes[0] = [skeleton, "v_before", "a", "b"]
  ordered_with_vnodes[1] = [skeleton, "rank1_only"]

  let rem_groups = build_seeded_remincross(
    base_groups,
    ordered_with_vnodes,
    Map::new(),
  )

  assert_eq(rem_groups.get(0), Some(["v_before", "a", "b"]))
  assert_eq(rem_groups.get(1), Some(["rank1_only"]))
}
