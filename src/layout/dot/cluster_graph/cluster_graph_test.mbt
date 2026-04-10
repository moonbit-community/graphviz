// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "cluster graph helpers detect cluster subgraphs and recurse through nesting" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_a = root.subgraph(name="cluster_a")
  let plain = root.subgraph(name="plain")
  let cluster_b = plain.subgraph(name="cluster_b")
  let isolated = root.subgraph(name="isolated")

  assert_true(is_cluster_graph(cluster_a))
  assert_false(is_cluster_graph(plain))
  assert_true(graph_has_cluster(root))
  assert_true(graph_has_cluster(plain))
  assert_false(graph_has_cluster(isolated))
  assert_false(graph_has_cluster(cluster_b))
}

///|
test "collect_cluster_graph_maps records cluster parents through non-cluster intermediates" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_a = root.subgraph(name="cluster_a")
  let plain = root.subgraph(name="plain")
  ignore(plain.subgraph(name="cluster_b"))
  ignore(cluster_a.subgraph(name="cluster_c"))

  let maps = collect_cluster_graph_maps(root)
  assert_eq(maps.cluster_graphs.length(), 3)
  assert_eq(maps.cluster_graphs.get("cluster_a") is Some(_), true)
  assert_eq(maps.cluster_graphs.get("cluster_b") is Some(_), true)
  assert_eq(maps.cluster_graphs.get("cluster_c") is Some(_), true)

  assert_eq(maps.cluster_parents.get("cluster_a"), Some(None))
  assert_eq(maps.cluster_parents.get("cluster_b"), Some(None))
  assert_eq(maps.cluster_parents.get("cluster_c"), Some(Some("cluster_a")))
}

///|
test "collect_cluster_names and collect_graph_nodes traverse all nested subgraphs" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(root.node("root_node"))
  let cluster_a = root.subgraph(name="cluster_a")
  ignore(cluster_a.node("a1"))
  let plain = root.subgraph(name="plain")
  ignore(plain.node("p1"))
  let cluster_b = plain.subgraph(name="cluster_b")
  ignore(cluster_b.node("b1"))

  let cluster_names : Map[String, Bool] = Map::new()
  collect_cluster_names(root, cluster_names)
  assert_eq(cluster_names.length(), 2)
  assert_eq(cluster_names.get("cluster_a"), Some(true))
  assert_eq(cluster_names.get("cluster_b"), Some(true))

  let nodes_out : Map[String, Bool] = Map::new()
  collect_graph_nodes(root, nodes_out)
  assert_eq(nodes_out.length(), 4)
  assert_eq(nodes_out.get("root_node"), Some(true))
  assert_eq(nodes_out.get("a1"), Some(true))
  assert_eq(nodes_out.get("p1"), Some(true))
  assert_eq(nodes_out.get("b1"), Some(true))
}
