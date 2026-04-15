// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "graph_contains_node and cluster keys follow nested cluster membership" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = root.node("a")
  let b = root.node("b")
  let c = root.node("c")
  let outer = root.subgraph(name="cluster_outer")
  let bridge = outer.subgraph(name="bridge")
  let inner = bridge.subgraph(name="cluster_inner")
  let nested_ref = inner.node("a")
  ignore(outer.node("a"))
  ignore(outer.node("b"))
  ignore(root.subgraph(name="free").node("c"))

  assert_true(root_graph_for_node(nested_ref).is_root())
  assert_true(graph_contains_node(outer, a))
  assert_true(graph_contains_node(inner, a))
  assert_true(graph_contains_node(outer, b))
  assert_false(graph_contains_node(inner, b))
  assert_eq(node_cluster_key(a), "cluster_outer")
  assert_eq(node_local_cluster_key(a), "cluster_inner")
  assert_eq(node_cluster_key(b), "cluster_outer")
  assert_eq(node_local_cluster_key(b), "cluster_outer")
  assert_eq(node_cluster_key(c), "")
  assert_eq(node_local_cluster_key(c), "")

  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(root)
  let members = collect_cluster_members(cluster_maps.cluster_graphs)
  let outer_members = match members.get("cluster_outer") {
    Some(value) => value
    None => fail("missing cluster_outer members")
  }
  let inner_members = match members.get("cluster_inner") {
    Some(value) => value
    None => fail("missing cluster_inner members")
  }

  assert_eq(outer_members.length(), 2)
  assert_eq(outer_members.get("a"), Some(true))
  assert_eq(outer_members.get("b"), Some(true))
  assert_eq(inner_members.length(), 1)
  assert_eq(inner_members.get("a"), Some(true))
}

///|
test "graph_contains_node excludes nodes pulled into external rank sets" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = root.node("a")
  let cluster = root.subgraph(name="cluster_outer")
  ignore(cluster.node("a"))
  let rankset = root.subgraph(name="same_rank")
  rankset.set_attr("rank", "same")
  ignore(rankset.node("a"))

  assert_false(graph_contains_node(cluster, a))
  assert_eq(node_cluster_key(a), "")
  assert_eq(node_local_cluster_key(a), "")

  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(root)
  let members = collect_cluster_members(cluster_maps.cluster_graphs)
  assert_true(members.get("cluster_outer") is None)
}

///|
test "collect_edge_cluster_keys uses outermost cluster ownership and cluster order skips nested clusters" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = root.node("a")
  let b = root.node("b")
  let c = root.node("c")
  let outer = root.subgraph(name="cluster_outer")
  let nested = outer.subgraph(name="cluster_nested")
  let child_plain = outer.subgraph(name="child_plain")
  let plain = root.subgraph(name="plain")
  let plain_cluster = plain.subgraph(name="cluster_plain")

  let outer_edge = outer.edge(a, b, name="outer")
  let nested_edge = nested.edge(b, c, name="nested")
  let child_edge = child_plain.edge(a, c, name="child")
  let plain_edge = plain_cluster.edge(c, a, name="plain_cluster")

  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(root, edge_cluster_keys)

  assert_eq(
    edge_cluster_keys.get(@edge_identity.edge_key(outer_edge)),
    Some("cluster_outer"),
  )
  assert_eq(
    edge_cluster_keys.get(@edge_identity.edge_key(nested_edge)),
    Some("cluster_outer"),
  )
  assert_eq(
    edge_cluster_keys.get(@edge_identity.edge_key(plain_edge)),
    Some("cluster_plain"),
  )
  assert_eq(edge_cluster_keys.get(@edge_identity.edge_key(child_edge)), None)

  let order : Array[String] = []
  collect_cluster_names_order(root, order)
  let expected : Array[String] = ["cluster_outer", "cluster_plain"]
  assert_eq(order, expected)
}

///|
test "cluster_lca walks parent chains and tolerates cycles" {
  let cluster_parents : Map[String, String?] = Map::new()
  cluster_parents["cluster_inner"] = Some("cluster_outer")
  cluster_parents["cluster_outer"] = None
  cluster_parents["cluster_sibling"] = Some("cluster_outer")
  cluster_parents["cluster_other"] = None
  cluster_parents["cycle_a"] = Some("cycle_b")
  cluster_parents["cycle_b"] = Some("cycle_a")

  assert_eq(
    cluster_lca("cluster_inner", "cluster_sibling", cluster_parents),
    "cluster_outer",
  )
  assert_eq(
    cluster_lca("cluster_inner", "cluster_outer", cluster_parents),
    "cluster_outer",
  )
  assert_eq(
    cluster_lca("cluster_inner", "cluster_inner", cluster_parents),
    "cluster_inner",
  )
  assert_eq(cluster_lca("cluster_inner", "cluster_other", cluster_parents), "")
  assert_eq(cluster_lca("", "cluster_outer", cluster_parents), "")
  assert_eq(cluster_lca("cycle_a", "cluster_other", cluster_parents), "")
}
