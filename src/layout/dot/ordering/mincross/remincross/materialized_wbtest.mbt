///|
fn materialized_entry_penalty(
  entry : (String, String, Int, Bool, Double, Double, Double, Double),
) -> Int {
  let (_, _, penalty, _, _, _, _, _) = entry
  penalty
}

///|
test "apply_intercluster_bonus adds the bonus only to the first representative of each merge key" {
  let coalesced : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  coalesced["tail0"] = [
    ("v1", "b", 2, true, 0.0, 0.0, 0.0, 0.0),
    ("v1", "b", 5, true, 1.0, 1.0, 0.0, 0.0),
  ]
  let bonus : Map[String, Int] = Map::new()
  bonus[@order_graph.order_edge_merge_key("v1", "b", true, 0.0, 0.0)] = 3

  let adjusted = apply_intercluster_bonus(coalesced, bonus)
  let entries = match adjusted.get("tail0") {
    Some(value) => value
    None => fail("missing adjusted tail bucket")
  }

  assert_eq(entries.length(), 2)
  assert_eq(materialized_entry_penalty(entries[0]), 5)
  assert_eq(materialized_entry_penalty(entries[1]), 5)
}

///|
test "collect_intercluster_bonus counts duplicated vnode-tail intercluster segments" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  edge_1.set_attr("xpenalty", "2")
  edge_2.set_attr("xpenalty", "2")

  let shared_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}shared_0"
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_1)] = [shared_vnode]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_2)] = [shared_vnode]

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["a"] = [0, 1]

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_left"
  cluster_keys["b"] = "cluster_right"

  let bonus = collect_intercluster_bonus(
    ["a"],
    [edge_1, edge_2],
    [],
    [],
    [],
    [],
    { "a": 0, "b": 2 },
    edge_vnodes,
    true,
    true,
    edges_by_tail,
    cluster_keys,
  )

  let bonus_key = @order_graph.order_edge_merge_key(
    shared_vnode, "b", true, 0.0, 0.5,
  )
  assert_eq(bonus.get(bonus_key), Some(1))
}

///|
test "build_remincross_cluster_keys rewrites empty root keys and assigns vnode LCAs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let edge_ab = graph.edge(a, b)
  let edge_cd = graph.edge(c, d)

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_ab)] = ["v_ab"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cd)] = ["v_cd"]

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster_left"
  intercluster_keys["b"] = ""
  intercluster_keys["c"] = "cluster_inner"
  intercluster_keys["d"] = "cluster_sibling"

  let cluster_parents : Map[String, String?] = Map::new()
  cluster_parents["cluster_left"] = None
  cluster_parents["cluster_outer"] = None
  cluster_parents["cluster_inner"] = Some("cluster_outer")
  cluster_parents["cluster_sibling"] = Some("cluster_outer")

  let rem_cluster_keys = build_remincross_cluster_keys({
    root_cluster: "__root__",
    edges: [edge_ab, edge_cd],
    edge_tail: [],
    edge_head: [],
    edge_vnodes,
    intercluster_keys,
    cluster_parents,
    order_with_vnodes: true,
  })

  assert_eq(rem_cluster_keys.get("a"), Some("cluster_left"))
  assert_eq(rem_cluster_keys.get("b"), Some("__root__"))
  assert_eq(rem_cluster_keys.get("v_ab"), Some("__root__"))
  assert_eq(rem_cluster_keys.get("v_cd"), Some("cluster_outer"))
}

///|
test "build_cluster_tail_order sorts non-root clusters by order index and keeps root override last" {
  let rem_order_creation = ["root_a", "c1_low", "c2_only", "c1_high", "root_b"]

  let rem_ranks : Map[String, Int] = Map::new()
  rem_ranks["root_a"] = 0
  rem_ranks["root_b"] = 0
  rem_ranks["c1_low"] = 0
  rem_ranks["c1_high"] = 1
  rem_ranks["c2_only"] = 0

  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["root_a"] = ""
  rem_cluster_keys["root_b"] = ""
  rem_cluster_keys["c1_low"] = "cluster1"
  rem_cluster_keys["c1_high"] = "cluster1"
  rem_cluster_keys["c2_only"] = "cluster2"

  let cluster_order_index : Map[String, Int] = Map::new()
  cluster_order_index["cluster1"] = 0
  cluster_order_index["cluster2"] = 1

  let order = build_cluster_tail_order(
    rem_order_creation,
    rem_ranks,
    rem_cluster_keys,
    [],
    cluster_order_index,
    Some(["root_b", "root_a"]),
  )

  assert_eq(order, ["c2_only", "c1_high", "c1_low", "root_b", "root_a"])
}

///|
test "build_remincross_nlist_order reverses deduped creation replay for single-cluster materialization" {
  let rem_vnode_creation : Map[String, Array[String]] = Map::new()
  rem_vnode_creation["tail_a"] = ["v_shared", "v_shared"]
  rem_vnode_creation["tail_b"] = ["v_shared", "v_tail_b"]

  let order = build_remincross_nlist_order(
    ["tail_a", "tail_b"],
    rem_vnode_creation,
    [],
    Map::new(),
    Map::new(),
    Map::new(),
    None,
  )

  assert_eq(order, ["v_tail_b", "tail_b", "v_shared", "tail_a"])
}

///|
test "build_remincross_flat_constraints merges rank-same locks only for non-cluster replay" {
  let flat_constraints = build_remincross_flat_constraints({
    order_with_clusters: false,
    cluster_flat_constraints: { "a|b": false, "b|c": true },
    rank_same_constraints: { "a|b": false, "c|d": false },
  })
  let clustered_constraints = build_remincross_flat_constraints({
    order_with_clusters: true,
    cluster_flat_constraints: { "a|b": false },
    rank_same_constraints: { "c|d": false },
  })

  assert_eq(flat_constraints.get("a|b"), Some(true))
  assert_eq(flat_constraints.get("b|c"), Some(true))
  assert_eq(flat_constraints.get("c|d"), Some(true))
  assert_eq(flat_constraints.length(), 3)
  assert_eq(clustered_constraints.length(), 0)
}

///|
test "cluster_key_for_tail_name prefers explicit keys and only falls back for rank-qualified skeleton names" {
  let skeleton = @cluster_identity.cluster_skeleton_name("parsed_cluster", 2)
  let explicit_keys : Map[String, String] = Map::new()
  explicit_keys[skeleton] = "explicit_cluster"

  assert_eq(
    cluster_key_for_tail_name(explicit_keys, skeleton),
    "explicit_cluster",
  )
  assert_eq(cluster_key_for_tail_name(Map::new(), skeleton), "parsed_cluster")
  assert_eq(
    cluster_key_for_tail_name(
      Map::new(),
      "\{@cluster_identity.CLUSTER_SKELETON_PREFIX}parsed_cluster",
    ),
    "",
  )
}

///|
test "build_remincross_order uses first-seen order to break equal cluster priorities and keeps root last" {
  let order = build_remincross_order(
    ["cluster_b", "", "cluster_a", "cluster_c"],
    { "cluster_b": 0, "": 1, "cluster_a": 2, "cluster_c": 3 },
    { "cluster_a": 5, "cluster_b": 5, "cluster_c": 1 },
  )

  assert_eq(order.cluster_order, ["cluster_b", "cluster_a", "cluster_c", ""])
  assert_eq(order.cluster_order_pos.get("cluster_b"), Some(0))
  assert_eq(order.cluster_order_pos.get("cluster_a"), Some(1))
  assert_eq(order.cluster_order_pos.get("cluster_c"), Some(2))
  assert_eq(order.cluster_order_pos.get(""), Some(3))
}

///|
test "build_nonroot_ordered_names keeps forward order only when every tail has no outgoing edges" {
  let rank_names = ["a", "b", "c"]
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["b"] = ["x"]

  assert_eq(build_nonroot_ordered_names(rank_names, Map::new()), rank_names)
  assert_eq(build_nonroot_ordered_names(rank_names, heads_by_tail), [
    "c", "b", "a",
  ])
}

///|
test "rebucket_input_like_order groups minimum-rank inputs by local fanout then later then earlier then neutral" {
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["i-neutral"] = ["same_1"]
  heads_by_tail["i-earlier"] = ["earlier_head"]
  heads_by_tail["i-later"] = ["later_head"]
  heads_by_tail["i-multi-local"] = ["same_1", "same_2"]

  let cluster_order_pos : Map[String, Int] = Map::new()
  cluster_order_pos["cluster_prev"] = 0
  cluster_order_pos["cluster_cur"] = 1
  cluster_order_pos["cluster_next"] = 2

  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["same_1"] = "cluster_cur"
  rem_cluster_keys["same_2"] = "cluster_cur"
  rem_cluster_keys["earlier_head"] = "cluster_prev"
  rem_cluster_keys["later_head"] = "cluster_next"

  let reordered = rebucket_input_like_order(
    "cluster_cur",
    ["i-neutral", "i-earlier", "i-later", "i-multi-local"],
    heads_by_tail,
    cluster_order_pos,
    ["cluster_prev", "cluster_cur", "cluster_next"],
    rem_cluster_keys,
  )

  assert_eq(reordered, ["i-multi-local", "i-later", "i-earlier", "i-neutral"])
}

///|
test "build_nonroot_tail_names replays higher ranks first and rebuckets only the minimum non-negative input-like rank" {
  let names = [
    "unknown", "i-neutral", "i-earlier", "i-later", "i-multi-local", "x1", "x2",
  ]
  let rem_ranks : Map[String, Int] = Map::new()
  rem_ranks["i-neutral"] = 0
  rem_ranks["i-earlier"] = 0
  rem_ranks["i-later"] = 0
  rem_ranks["i-multi-local"] = 0
  rem_ranks["x1"] = 1
  rem_ranks["x2"] = 1

  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["i-neutral"] = ["same_1"]
  heads_by_tail["i-earlier"] = ["earlier_head"]
  heads_by_tail["i-later"] = ["later_head"]
  heads_by_tail["i-multi-local"] = ["same_1", "same_2"]

  let cluster_order_pos : Map[String, Int] = Map::new()
  cluster_order_pos["cluster_prev"] = 0
  cluster_order_pos["cluster_cur"] = 1
  cluster_order_pos["cluster_next"] = 2

  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["same_1"] = "cluster_cur"
  rem_cluster_keys["same_2"] = "cluster_cur"
  rem_cluster_keys["earlier_head"] = "cluster_prev"
  rem_cluster_keys["later_head"] = "cluster_next"

  let ordered = build_nonroot_tail_names(
    "cluster_cur",
    names,
    rem_ranks,
    heads_by_tail,
    cluster_order_pos,
    ["cluster_prev", "cluster_cur", "cluster_next"],
    rem_cluster_keys,
  )

  assert_eq(ordered, [
    "x1", "x2", "i-multi-local", "i-later", "i-earlier", "i-neutral", "unknown",
  ])
}

///|
test "build_cluster_tail_buckets groups creation replay by first-seen cluster including skeleton fallback names" {
  let cluster1_skeleton = @cluster_identity.cluster_skeleton_name("cluster1", 2)
  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["root_a"] = ""
  rem_cluster_keys["c1_a"] = "cluster1"
  rem_cluster_keys["c2_a"] = "cluster2"
  rem_cluster_keys["c1_b"] = "cluster1"

  let buckets = build_cluster_tail_buckets(
    ["root_a", cluster1_skeleton, "c2_a", "c1_a", "c1_b"],
    rem_cluster_keys,
  )

  assert_eq(buckets.cluster_order_seen, ["", "cluster1", "cluster2"])
  assert_eq(buckets.names_by_cluster.get(""), Some(["root_a"]))
  assert_eq(
    buckets.names_by_cluster.get("cluster1"),
    Some([cluster1_skeleton, "c1_a", "c1_b"]),
  )
  assert_eq(buckets.names_by_cluster.get("cluster2"), Some(["c2_a"]))
  assert_eq(buckets.cluster_first_seen.get(""), Some(0))
  assert_eq(buckets.cluster_first_seen.get("cluster1"), Some(1))
  assert_eq(buckets.cluster_first_seen.get("cluster2"), Some(2))
}

///|
test "build_cluster_tail_names_for_cluster applies root override only to names present in the root bucket" {
  let root_names = ["root_a", "root_c", "root_b"]
  let context : ClusterTailOrderContext = {
    rem_ranks: Map::new(),
    heads_by_tail: Map::new(),
    cluster_order_pos: Map::new(),
    cluster_order: [""],
    rem_cluster_keys: Map::new(),
    root_tail_order_override: Some(["root_b", "missing", "root_a"]),
  }

  let reordered = build_cluster_tail_names_for_cluster("", root_names, context)

  assert_eq(reordered, ["root_b", "root_a", "root_c"])
}
