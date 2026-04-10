// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "apply_rank_same_order_nodes rewrites node order for unported groups only" {
  let node_order : Map[String, Int] = Map::new()
  node_order["a"] = 2
  node_order["b"] = 5
  node_order["c"] = 9
  node_order["d"] = 7

  let rank_same_groups : Map[String, Int] = Map::new()
  rank_same_groups["a"] = 1
  rank_same_groups["b"] = 1
  rank_same_groups["c"] = 2
  rank_same_groups["d"] = 2

  let rank_same_order : Map[String, Int] = Map::new()
  rank_same_order["b"] = 0
  rank_same_order["a"] = 1
  rank_same_order["d"] = 0
  rank_same_order["c"] = 1

  let port_edge_nodes : Map[String, Bool] = Map::new()
  port_edge_nodes["c"] = true

  apply_rank_same_order_nodes(
    node_order, rank_same_groups, rank_same_order, port_edge_nodes,
  )

  assert_eq(node_order.get("b"), Some(2))
  assert_eq(node_order.get("a"), Some(5))
  assert_eq(node_order.get("c"), Some(9))
  assert_eq(node_order.get("d"), Some(7))
}

///|
test "build_order_reorder_context assembles rank keys graphs creation order and node-order fallbacks on noncluster path" {
  let order_groups : Map[Int, Array[String]] = Map::new()
  order_groups[0] = ["a", "b", "v0"]
  order_groups[1] = ["d"]

  let context = build_order_reorder_context({
    order_groups,
    nlist_order: ["a", "v0"],
    gdnlist_order: ["a", "b"],
    node_order: { "c": 7 },
    real_nodes: {
      "a": true,
      "b": true,
      "c": true,
      "d": true,
      "extra_real": true,
    },
    has_clusters: false,
    base_order_index: { "extra_real": 11, "a": 99 },
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: Map::new(),
  })

  assert_eq(context.order_rank_keys, [0, 1])
  assert_eq(context.order_ranks.get("a"), Some(0))
  assert_eq(context.order_ranks.get("b"), Some(0))
  assert_eq(context.order_ranks.get("v0"), Some(0))
  assert_eq(context.order_ranks.get("d"), Some(1))
  assert_eq(context.order_nodes, ["a", "b", "v0", "d"])
  assert_eq(context.creation_order, ["v0", "a"])
  assert_true(context.order_node_map.get("a") is Some(_))
  assert_true(context.order_node_map_unmapped.get("d") is Some(_))
  assert_true(context.order_node_map.get("extra_real") is None)
  assert_eq(context.order_node_order.get("a"), Some(0))
  assert_eq(context.order_node_order.get("b"), Some(1))
  assert_eq(context.order_node_order.get("v0"), Some(2))
  assert_eq(context.order_node_order.get("c"), Some(7))
  assert_eq(context.order_node_order.get("d"), Some(0))
  assert_eq(context.order_node_order.get("extra_real"), Some(11))
}

///|
test "build_order_reorder_context applies rank-same normalization only when clusters are enabled" {
  let order_groups : Map[Int, Array[String]] = Map::new()
  order_groups[0] = ["a", "b"]
  let empty_nlist : Array[String] = []
  let empty_node_order : Map[String, Int] = Map::new()
  let empty_base_order_index : Map[String, Int] = Map::new()
  let empty_port_edge_nodes : Map[String, Bool] = Map::new()

  let nonclustered = build_order_reorder_context({
    order_groups,
    nlist_order: empty_nlist,
    gdnlist_order: ["a", "b"],
    node_order: empty_node_order,
    real_nodes: { "a": true, "b": true },
    has_clusters: false,
    base_order_index: empty_base_order_index,
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: empty_port_edge_nodes,
  })
  let clustered = build_order_reorder_context({
    order_groups,
    nlist_order: empty_nlist,
    gdnlist_order: ["a", "b"],
    node_order: empty_node_order,
    real_nodes: { "a": true, "b": true },
    has_clusters: true,
    base_order_index: empty_base_order_index,
    rank_same_groups: { "a": 1, "b": 1 },
    rank_same_order: { "b": 0, "a": 1 },
    port_edge_nodes: empty_port_edge_nodes,
  })

  assert_eq(nonclustered.order_node_order.get("a"), Some(0))
  assert_eq(nonclustered.order_node_order.get("b"), Some(1))
  assert_eq(clustered.order_node_order.get("b"), Some(0))
  assert_eq(clustered.order_node_order.get("a"), Some(1))
}

///|
test "apply_unconstrained_order_overrides resets isolated real nodes to gdnlist order while leaving constrained and rank-same nodes untouched" {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["connected"] = ["sink"]

  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["connected"] = 90
  order_node_order["isolated_b"] = 91
  order_node_order["isolated_a"] = 92
  order_node_order["rank_locked"] = 93

  let nodes : Array[@cgraph.Node] = []

  apply_unconstrained_order_overrides(
    ["connected", "isolated_b", "isolated_a", "rank_locked"],
    {
      "connected": true,
      "isolated_b": true,
      "isolated_a": true,
      "rank_locked": true,
    },
    ["connected", "isolated_b", "isolated_a", "rank_locked"],
    graphviz_out_neighbors,
    Map::new(),
    { "rank_locked": 1 },
    [],
    [],
    nodes,
    Map::new(),
    order_node_order,
  )

  assert_eq(order_node_order.get("connected"), Some(90))
  assert_eq(order_node_order.get("isolated_b"), Some(1))
  assert_eq(order_node_order.get("isolated_a"), Some(2))
  assert_eq(order_node_order.get("rank_locked"), Some(93))
}

///|
test "apply_unconstrained_order_overrides reassigns incoming-only local cluster nodes by first incoming edge order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let local_a = graph.node("local_a")
  let local_b = graph.node("local_b")

  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["local_a"] = []
  graphviz_out_neighbors["local_b"] = []

  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_in_neighbors["local_a"] = []
  graphviz_in_neighbors["local_b"] = []

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["local_a"] = "cluster_local"
  intercluster_keys["local_b"] = "cluster_local"

  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["local_a"] = 10
  order_node_order["local_b"] = 20

  apply_unconstrained_order_overrides(
    [],
    Map::new(),
    ["local_a", "local_b"],
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    Map::new(),
    ["tail_to_b", "tail_to_a"],
    ["local_b", "local_a"],
    [local_a, local_b],
    intercluster_keys,
    order_node_order,
  )

  assert_eq(order_node_order.get("local_b"), Some(10))
  assert_eq(order_node_order.get("local_a"), Some(20))
}
