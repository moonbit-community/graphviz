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
