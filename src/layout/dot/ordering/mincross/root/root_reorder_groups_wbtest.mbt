///|
test "build_root_reorder_groups keeps root and skeleton names and inserts only cross-cluster edge vnodes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root_a = graph.node("root_a")
  let cluster_member = graph.node("cluster_member")
  let cluster_peer = graph.node("cluster_peer")
  let edge_cross = graph.edge(root_a, cluster_member)
  let edge_local = graph.edge(cluster_member, cluster_peer)

  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)

  let order_groups_for_mincross : Map[Int, Array[String]] = Map::new()
  order_groups_for_mincross[0] = ["root_a", skeleton_0, "cluster_member"]
  order_groups_for_mincross[1] = ["cluster_peer", "root_b"]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys[skeleton_0] = "cluster_x"
  order_cluster_keys["cluster_member"] = "cluster_x"
  order_cluster_keys["cluster_peer"] = "cluster_x"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skeleton_0] = true

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_member"] = "cluster_x"
  cluster_keys["cluster_peer"] = "cluster_x"

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cross)] = ["v_cross"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_local)] = ["v_local"]

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v_cross", "v_local"]

  let vnode_order_keys_for_ordering : Map[String, Double] = Map::new()
  vnode_order_keys_for_ordering["v_cross"] = 0.5
  vnode_order_keys_for_ordering["v_local"] = 0.25

  let root_groups = build_root_reorder_groups(
    true,
    [0, 1],
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    [edge_cross, edge_local],
    [],
    [],
    cluster_keys,
    edge_vnodes,
    vnodes_by_rank,
    vnode_order_keys_for_ordering,
  )

  assert_eq(root_groups.get(0), Some(["root_a", "v_cross", skeleton_0]))
  assert_eq(root_groups.get(1), Some(["root_b"]))
}

///|
test "collect_root_vnodes keeps only edge vnodes from edges that cross cluster boundaries when enabled" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root_a = graph.node("root_a")
  let cluster_member = graph.node("cluster_member")
  let cluster_peer = graph.node("cluster_peer")
  let root_b = graph.node("root_b")
  let edge_cross = graph.edge(root_a, cluster_member)
  let edge_local = graph.edge(cluster_member, cluster_peer)
  let edge_root = graph.edge(root_a, root_b)

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_member"] = "cluster_x"
  cluster_keys["cluster_peer"] = "cluster_x"

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cross)] = [
    "v_cross_0", "v_cross_1",
  ]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_local)] = ["v_local"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_root)] = ["v_root"]

  let enabled = collect_root_vnodes(
    true,
    [edge_cross, edge_local, edge_root],
    [],
    [],
    cluster_keys,
    edge_vnodes,
  )
  let disabled = collect_root_vnodes(
    false,
    [edge_cross, edge_local, edge_root],
    [],
    [],
    cluster_keys,
    edge_vnodes,
  )

  assert_eq(enabled.get("v_cross_0"), Some(true))
  assert_eq(enabled.get("v_cross_1"), Some(true))
  assert_true(enabled.get("v_local") is None)
  assert_true(enabled.get("v_root") is None)
  assert_eq(disabled.length(), 0)
}

///|
test "build_root_vnode_inputs keeps only marked root vnodes in rank buckets and order keys" {
  let root_vnodes : Map[String, Bool] = Map::new()
  root_vnodes["v_keep"] = true
  root_vnodes["v_keep_2"] = true

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v_drop", "v_keep"]
  vnodes_by_rank[2] = ["v_keep_2"]

  let vnode_order_keys_for_ordering : Map[String, Double] = Map::new()
  vnode_order_keys_for_ordering["v_keep"] = 0.5
  vnode_order_keys_for_ordering["v_keep_2"] = 1.5
  vnode_order_keys_for_ordering["v_drop"] = 9.0

  let (enabled_by_rank, enabled_keys) = build_root_vnode_inputs(
    true, root_vnodes, vnodes_by_rank, vnode_order_keys_for_ordering,
  )
  let (disabled_by_rank, disabled_keys) = build_root_vnode_inputs(
    false, root_vnodes, vnodes_by_rank, vnode_order_keys_for_ordering,
  )

  assert_eq(enabled_by_rank.get(0), Some(["v_keep"]))
  assert_eq(enabled_by_rank.get(2), Some(["v_keep_2"]))
  assert_eq(enabled_keys.get("v_keep"), Some(0.5))
  assert_eq(enabled_keys.get("v_keep_2"), Some(1.5))
  assert_true(enabled_keys.get("v_drop") is None)
  assert_eq(disabled_by_rank.length(), 0)
  assert_eq(disabled_keys.length(), 0)
}

///|
test "should_keep_root_reorder_name keeps root names and skeletons but drops clustered non-skeletons and unmarked edge vnodes" {
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)
  let allowed_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}keep"
  let dropped_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}drop"

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys[skeleton_0] = "cluster_x"
  order_cluster_keys["cluster_member"] = "cluster_x"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skeleton_0] = true

  let root_vnodes : Map[String, Bool] = Map::new()
  root_vnodes[allowed_vnode] = true

  assert_true(
    should_keep_root_reorder_name(
      "root_real", order_cluster_keys, order_cluster_skeleton, root_vnodes,
    ),
  )
  assert_true(
    should_keep_root_reorder_name(
      skeleton_0, order_cluster_keys, order_cluster_skeleton, root_vnodes,
    ),
  )
  assert_true(
    should_keep_root_reorder_name(
      allowed_vnode, order_cluster_keys, order_cluster_skeleton, root_vnodes,
    ),
  )
  assert_false(
    should_keep_root_reorder_name(
      "cluster_member", order_cluster_keys, order_cluster_skeleton, root_vnodes,
    ),
  )
  assert_false(
    should_keep_root_reorder_name(
      dropped_vnode, order_cluster_keys, order_cluster_skeleton, root_vnodes,
    ),
  )
}
