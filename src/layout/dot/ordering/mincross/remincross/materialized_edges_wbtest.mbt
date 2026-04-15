// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
test "build_remincross_materialized_edges coalesces duplicate chains, applies vnode-tail bonus, and replays edge creation from real tails only" {
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

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster_left"
  intercluster_keys["b"] = "cluster_right"

  let materialized = build_remincross_materialized_edges(
    {
      rem_rank_keys: [0, 2],
      rem_groups: Map::new(),
      creation_order: ["a"],
      edges: [edge_1, edge_2],
      edge_tail: [],
      edge_head: [],
      edge_tail_port_x: [],
      edge_head_port_x: [],
      edge_tail_port_order: [],
      edge_head_port_order: [],
      ranks: { "a": 0, "b": 2 },
      edge_vnodes,
      order_with_vnodes: true,
      intercluster_keys,
      cluster_order: ["cluster_left", "cluster_right"],
      order_with_clusters: true,
      edges_by_tail,
      root_tail_order_override: None,
      root_cluster: "__root__",
      cluster_parents: Map::new(),
      order_sizes: Map::new(),
      vnode_sizes: Map::new(),
      cluster_flat_constraints: Map::new(),
      rank_same_constraints: Map::new(),
    },
    { "cluster_left": 0, "cluster_right": 1 },
  )

  assert_eq(materialized.vnode_creation.get("a"), Some([shared_vnode]))
  assert_eq(materialized.edge_creation, [("a", shared_vnode)])
  assert_eq(
    materialized.order_edges_by_tail
    .get("a")
    .map(fn(entries) { entries.map(materialized_entry_penalty) }),
    Some([4]),
  )
  assert_eq(
    materialized.order_edges_by_tail
    .get(shared_vnode)
    .map(fn(entries) { entries.map(materialized_entry_penalty) }),
    Some([5]),
  )
}

///|
test "build_remincross_materialized_edges replays edge creation in creation-order across multiple real tails" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")
  let edge_ab = graph.edge(a, b)
  let edge_cd = graph.edge(c, d)

  let vnode_ab = "\{@edge_identity.EDGE_VNODE_PREFIX}ab_0"
  let vnode_cd = "\{@edge_identity.EDGE_VNODE_PREFIX}cd_0"
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_ab)] = [vnode_ab]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cd)] = [vnode_cd]

  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  edges_by_tail["c"] = [1]
  edges_by_tail["a"] = [0]

  let materialized = build_remincross_materialized_edges(
    {
      rem_rank_keys: [0, 2],
      rem_groups: Map::new(),
      creation_order: ["c", "a"],
      edges: [edge_ab, edge_cd],
      edge_tail: [],
      edge_head: [],
      edge_tail_port_x: [],
      edge_head_port_x: [],
      edge_tail_port_order: [],
      edge_head_port_order: [],
      ranks: { "a": 0, "b": 2, "c": 0, "d": 2 },
      edge_vnodes,
      order_with_vnodes: true,
      intercluster_keys: Map::new(),
      cluster_order: [],
      order_with_clusters: false,
      edges_by_tail,
      root_tail_order_override: None,
      root_cluster: "__root__",
      cluster_parents: Map::new(),
      order_sizes: Map::new(),
      vnode_sizes: Map::new(),
      cluster_flat_constraints: Map::new(),
      rank_same_constraints: Map::new(),
    },
    Map::new(),
  )

  assert_eq(materialized.vnode_creation.get("c"), Some([vnode_cd]))
  assert_eq(materialized.vnode_creation.get("a"), Some([vnode_ab]))
  assert_eq(materialized.edge_creation, [("c", vnode_cd), ("a", vnode_ab)])
}
