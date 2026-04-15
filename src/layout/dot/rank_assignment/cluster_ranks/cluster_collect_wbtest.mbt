// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "collect_top_clusters keeps only top-level clusters and excludes the cluster source itself" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let outer = root.subgraph(name="cluster_outer")
  let peer = root.subgraph(name="cluster_peer")
  let inner = outer.subgraph(name="cluster_inner")
  ignore(outer.node("a"))
  ignore(peer.node("b"))
  ignore(inner.node("c"))

  let root_collected = collect_top_clusters(root)
  let root_top : Map[String, Bool] = Map::new()
  for name in root_collected.top_clusters {
    root_top[name] = true
  }
  assert_eq(root_top.length(), 2)
  assert_eq(root_top.get("cluster_outer"), Some(true))
  assert_eq(root_top.get("cluster_peer"), Some(true))
  assert_eq(root_top.get("cluster_inner"), None)

  let cluster_collected = collect_top_clusters(outer)
  assert_eq(cluster_collected.top_clusters.length(), 0)
  assert_eq(cluster_collected.cluster_graphs.length(), 2)
  match cluster_collected.cluster_graphs.get("cluster_outer") {
    Some(_) => ()
    None => fail("missing cluster_outer graph")
  }
  match cluster_collected.cluster_graphs.get("cluster_inner") {
    Some(_) => ()
    None => fail("missing cluster_inner graph")
  }
}

///|
test "collect_cluster_members omits empty clusters and node index ignores missing member maps" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let empty = root.subgraph(name="cluster_empty")
  let full = root.subgraph(name="cluster_full")
  ignore(empty)
  ignore(full.node("a"))

  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(root)
  let members = collect_cluster_members(cluster_maps.cluster_graphs)

  assert_eq(members.get("cluster_empty"), None)
  let full_members = match members.get("cluster_full") {
    Some(value) => value
    None => fail("missing cluster_full members")
  }
  assert_eq(full_members.length(), 1)
  assert_eq(full_members.get("a"), Some(true))

  let node_cluster = build_node_cluster_index(
    ["cluster_missing", "cluster_full"],
    members,
  )
  assert_eq(node_cluster.length(), 1)
  assert_eq(node_cluster.get("a"), Some("cluster_full"))
  assert_eq(node_cluster.get("b"), None)
}
