// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "non-adjacent flat edge appends label vnode after existing edge vnodes and falls back to edge cluster key" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let c = graph.node("c")
  let b = graph.node("b")
  ignore(c)
  let edge = graph.edge(a, b)
  edge.set_attr("label", "cluster-fallback")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["c"] = 0

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "c", "b"]
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "c", "b"]
  let sizes = make_sizes(["a", "b", "c"], 10.0, 10.0)

  let vnode_info = empty_vnode_info()
  let preexisting_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}pre"
  vnode_info.vnode_ranks[preexisting_vnode] = 0
  vnode_info.edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [
    preexisting_vnode,
  ]

  let edge_cluster_keys : Map[String, String] = Map::new()
  edge_cluster_keys[@edge_identity.edge_key(edge)] = "cluster_edge"

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::TB,
    sizes,
    edge_cluster_keys,
    Map::new(),
    make_existing_names(["a", "b", "c", preexisting_vnode]),
    vnode_info,
    x_groups,
  )

  let label_vnode = match
    result.flat_label_edge_vnodes.get(@edge_identity.edge_key(edge)) {
    Some(value) => value
    None => fail("expected flat label vnode mapping")
  }

  assert_eq(result.flat_label_ranks.get(label_vnode), Some(-1))
  assert_eq(result.x_groups.get(-1).unwrap_or([]), [label_vnode])
  assert_eq(vnode_info.vnodes_by_rank.get(-1).unwrap_or([]), [label_vnode])
  assert_eq(
    vnode_info.edge_vnodes
    .get(@edge_identity.edge_vnode_key(edge))
    .unwrap_or([]),
    [preexisting_vnode, label_vnode],
  )
  assert_eq(vnode_info.vnode_clusters.get(label_vnode), Some("cluster_edge"))
}

///|
test "non-adjacent flat edge prefers endpoint cluster membership over edge cluster fallback" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  let c = graph.node("c")
  ignore(c)
  let edge = graph.edge(a, b)
  edge.set_attr("label", "cluster-membership")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["c"] = 0

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "c", "b"]
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "c", "b"]
  let sizes = make_sizes(["a", "b", "c"], 10.0, 10.0)

  let vnode_info = empty_vnode_info()
  let edge_cluster_keys : Map[String, String] = Map::new()
  edge_cluster_keys[@edge_identity.edge_key(edge)] = "wrong_cluster"

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::TB,
    sizes,
    edge_cluster_keys,
    Map::new(),
    make_existing_names(["a", "b", "c"]),
    vnode_info,
    x_groups,
  )

  let label_vnode = match
    result.flat_label_edge_vnodes.get(@edge_identity.edge_key(edge)) {
    Some(value) => value
    None => fail("expected flat label vnode mapping")
  }

  assert_eq(result.flat_label_ranks.get(label_vnode), Some(-1))
  assert_eq(vnode_info.vnode_clusters.get(label_vnode), Some("cluster_0"))
}
