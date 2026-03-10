///|
test "build_root_tail_order_seed replaces clustered names with rank-qualified skeletons and dedupes repeats" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_a_0"] = "cluster_a"
  cluster_keys["cluster_a_0_dup"] = "cluster_a"
  cluster_keys["cluster_a_1"] = "cluster_a"
  cluster_keys["cluster_b_0"] = "cluster_b"

  let ranks : Map[String, Int] = Map::new()
  ranks["cluster_a_0"] = 0
  ranks["cluster_a_0_dup"] = 0
  ranks["cluster_a_1"] = 1
  ranks["cluster_b_0"] = 0

  let tail_order = build_root_tail_order_seed(
    [
      "root", "cluster_a_0", "cluster_a_0_dup", "cluster_a_1", "cluster_b_0", "root",
    ],
    cluster_keys,
    ranks,
  )

  assert_eq(tail_order, [
    "root",
    @cluster_identity.cluster_skeleton_name("cluster_a", 0),
    @cluster_identity.cluster_skeleton_name("cluster_a", 1),
    @cluster_identity.cluster_skeleton_name("cluster_b", 0),
  ])
}

///|
test "build_root_source_first_tail_order moves source tails ahead while preserving original order within each bucket" {
  let tail_order = build_root_source_first_tail_order(
    ["mid", "src1", "sink", "src2"],
    ["src1", "src2", "mid", "sink"],
    [("src1", "mid"), ("mid", "sink")],
  )

  assert_eq(tail_order, ["src1", "src2", "mid", "sink"])
}

///|
test "finalize_root_nlist_order keeps only materialized nodes then appends missing root nodes in root order" {
  let root_nodes = ["a", "b", "c", "d"]
  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_nlist_finalize", root_nodes,
  )

  let finalized = finalize_root_nlist_order(
    ["ghost", "c", "a"],
    root_nodes,
    graph_output.order_node_map,
  )

  assert_eq(finalized, ["c", "a", "b", "d"])
}

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
test "build_root_reorder_node_order prefers nlist order for materialized nodes and backfills missing names from rank-group order" {
  let root_groups : Map[Int, Array[String]] = Map::new()
  root_groups[0] = ["a", "c"]
  root_groups[1] = ["b"]

  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_node_order",
    ["a", "b", "c"],
  )

  let node_order = build_root_reorder_node_order(
    ["ghost", "a", "b"],
    graph_output.order_node_map,
    root_groups,
  )

  assert_eq(node_order.get("a"), Some(0))
  assert_eq(node_order.get("b"), Some(1))
  assert_eq(node_order.get("c"), Some(1))
}
