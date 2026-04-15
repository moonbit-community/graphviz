// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "cluster_depth_for_order prefers explicit hints, ignores self-parent hints, and falls back to discovered parents" {
  let parents : Map[String, String?] = Map::new()
  parents["child"] = Some("hint_parent")
  parents["selfish"] = Some("selfish")

  let fallback_parents : Map[String, String?] = Map::new()
  fallback_parents["child"] = Some("fallback_parent")
  fallback_parents["hint_parent"] = Some("root")
  fallback_parents["orphan"] = Some("root")
  fallback_parents["selfish"] = Some("root")

  let memo : Map[String, Int] = Map::new()
  let child_depth = cluster_depth_for_order(
    "child", parents, fallback_parents, memo,
  )
  let selfish_depth = cluster_depth_for_order(
    "selfish", parents, fallback_parents, memo,
  )
  let orphan_depth = cluster_depth_for_order(
    "orphan", parents, fallback_parents, memo,
  )

  assert_eq(child_depth, 2)
  assert_eq(selfish_depth, 0)
  assert_eq(orphan_depth, 1)
  assert_eq(memo.get("child"), Some(2))
  assert_eq(memo.get("hint_parent"), Some(1))
  assert_eq(memo.get("selfish"), Some(0))
  assert_eq(memo.get("orphan"), Some(1))
}

///|
test "build_cluster_graph_order sorts same-depth clusters by cluster_order and keeps nested clusters after their parents" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_a = root.subgraph(name="cluster_a")
  let plain = root.subgraph(name="plain")
  ignore(plain.subgraph(name="cluster_b"))
  ignore(root.subgraph(name="cluster_c"))
  ignore(cluster_a.subgraph(name="cluster_d"))

  let ordered = build_cluster_graph_order(
    root,
    ["cluster_c", "cluster_b", "cluster_a", "cluster_d"],
    Map::new(),
  )

  assert_eq(ordered.cluster_graphs.length(), 4)
  assert_eq(ordered.cluster_names, [
    "cluster_c", "cluster_b", "cluster_a", "cluster_d",
  ])
}

///|
test "build_cluster_graph_order honors explicit parent hints before cluster_order tie-breaks" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(root.subgraph(name="cluster_a"))
  ignore(root.subgraph(name="cluster_b"))
  ignore(root.subgraph(name="cluster_c"))

  let cluster_parents_hint : Map[String, String?] = Map::new()
  cluster_parents_hint["cluster_b"] = Some("cluster_a")
  cluster_parents_hint["cluster_c"] = Some("cluster_b")

  let ordered = build_cluster_graph_order(
    root,
    ["cluster_c", "cluster_b", "cluster_a"],
    cluster_parents_hint,
  )

  assert_eq(ordered.cluster_names, ["cluster_a", "cluster_b", "cluster_c"])
}

///|
test "build_cluster_graph_order ignores self-parent hints and places unlisted same-depth clusters after listed ones" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(root.subgraph(name="cluster_a"))
  ignore(root.subgraph(name="cluster_b"))

  let cluster_parents_hint : Map[String, String?] = Map::new()
  cluster_parents_hint["cluster_a"] = Some("cluster_a")

  let ordered = build_cluster_graph_order(
    root,
    ["cluster_b"],
    cluster_parents_hint,
  )

  assert_eq(ordered.cluster_names, ["cluster_b", "cluster_a"])
}
