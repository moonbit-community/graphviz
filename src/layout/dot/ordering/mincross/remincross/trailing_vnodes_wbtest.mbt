///|
test "cluster_rank_ranges_overlap treats touching ranges as overlapping and falls back to min rank when max is missing" {
  let cluster_min_rank : Map[String, Int] = Map::new()
  cluster_min_rank["left"] = 0
  cluster_min_rank["touching"] = 1
  cluster_min_rank["far"] = 3

  let cluster_max_rank : Map[String, Int] = Map::new()
  cluster_max_rank["left"] = 1

  assert_true(
    cluster_rank_ranges_overlap(
      "left", "touching", cluster_min_rank, cluster_max_rank,
    ),
  )
  assert_false(
    cluster_rank_ranges_overlap(
      "left", "far", cluster_min_rank, cluster_max_rank,
    ),
  )
}

///|
test "collect_remincross_trailing keeps only non-root non-internal cross-cluster vnode chains whose rank ranges do not overlap" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let left = graph.node("left")
  let right = graph.node("right")
  let child = graph.node("child")
  let parent = graph.node("parent")
  let same_a = graph.node("same_a")
  let same_b = graph.node("same_b")
  let root = graph.node("root")
  let overlap_a = graph.node("overlap_a")
  let overlap_b = graph.node("overlap_b")

  let edge_disjoint = graph.edge(left, right)
  let edge_internal = graph.edge(child, parent)
  let edge_same = graph.edge(same_a, same_b)
  let edge_root = graph.edge(root, left)
  let edge_overlap = graph.edge(overlap_a, overlap_b)

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_disjoint)] = ["v_disjoint"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_internal)] = ["v_internal"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_same)] = ["v_same"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_root)] = ["v_root"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_overlap)] = ["v_overlap"]

  let remincross_cluster_keys : Map[String, String] = Map::new()
  remincross_cluster_keys["left"] = "cluster_left"
  remincross_cluster_keys["right"] = "cluster_right"
  remincross_cluster_keys["child"] = "cluster_child"
  remincross_cluster_keys["parent"] = "cluster_parent"
  remincross_cluster_keys["same_a"] = "cluster_same"
  remincross_cluster_keys["same_b"] = "cluster_same"
  remincross_cluster_keys["root"] = ""
  remincross_cluster_keys["overlap_a"] = "cluster_overlap_a"
  remincross_cluster_keys["overlap_b"] = "cluster_overlap_b"

  let cluster_parents : Map[String, String?] = Map::new()
  cluster_parents["cluster_child"] = Some("cluster_parent")
  cluster_parents["cluster_parent"] = None
  cluster_parents["cluster_left"] = None
  cluster_parents["cluster_right"] = None
  cluster_parents["cluster_same"] = None
  cluster_parents["cluster_overlap_a"] = None
  cluster_parents["cluster_overlap_b"] = None

  let cluster_min_rank : Map[String, Int] = Map::new()
  cluster_min_rank["cluster_left"] = 0
  cluster_min_rank["cluster_right"] = 2
  cluster_min_rank["cluster_child"] = 0
  cluster_min_rank["cluster_parent"] = 3
  cluster_min_rank["cluster_same"] = 1
  cluster_min_rank["cluster_overlap_a"] = 1
  cluster_min_rank["cluster_overlap_b"] = 2

  let cluster_max_rank : Map[String, Int] = Map::new()
  cluster_max_rank["cluster_left"] = 0
  cluster_max_rank["cluster_right"] = 2
  cluster_max_rank["cluster_child"] = 0
  cluster_max_rank["cluster_parent"] = 3
  cluster_max_rank["cluster_same"] = 1
  cluster_max_rank["cluster_overlap_a"] = 2
  cluster_max_rank["cluster_overlap_b"] = 3

  let trailing = collect_remincross_trailing(
    [edge_disjoint, edge_internal, edge_same, edge_root, edge_overlap],
    [],
    [],
    edge_vnodes,
    remincross_cluster_keys,
    cluster_parents,
    cluster_min_rank,
    cluster_max_rank,
  )

  assert_eq(trailing.get("v_disjoint"), Some(true))
  assert_true(trailing.get("v_internal") is None)
  assert_true(trailing.get("v_same") is None)
  assert_true(trailing.get("v_root") is None)
  assert_true(trailing.get("v_overlap") is None)
}

///|
test "apply_remincross_floor raises selected trailing vnodes behind the last real node on their rank" {
  let keys : Map[String, Double] = Map::new()
  keys["v_floor"] = 0.25
  keys["v_keep"] = 5.0

  let intercluster_vnodes : Map[String, Bool] = Map::new()
  intercluster_vnodes["v_floor"] = true
  intercluster_vnodes["v_keep"] = true

  let rem_base_order_index : Map[String, Int] = Map::new()
  rem_base_order_index["a"] = 0
  rem_base_order_index["b"] = 1
  rem_base_order_index["c"] = 0

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["c"] = 2

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v_floor"] = 0
  vnode_ranks["v_keep"] = 2

  apply_remincross_floor(
    keys, intercluster_vnodes, rem_base_order_index, ranks, vnode_ranks,
  )

  assert_eq(keys.get("v_floor"), Some(2.0))
  assert_eq(keys.get("v_keep"), Some(5.0))
}
