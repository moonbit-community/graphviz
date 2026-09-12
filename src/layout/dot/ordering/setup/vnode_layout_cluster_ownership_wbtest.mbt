// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "nested long-edge virtual nodes belong to the deepest common cluster" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let outer = graph.subgraph(name="cluster_outer")
  let inner = outer.subgraph(name="cluster_inner")
  let sibling = outer.subgraph(name="cluster_sibling")
  let a = inner.node("a")
  let b = inner.node("b")
  let c = sibling.node("c")
  let internal = graph.edge(a, b)
  let between = graph.edge(a, c)
  let info = build_edge_vnodes_for_test(
    graph,
    { "a": 0, "b": 2, "c": 2 },
    20.0,
    @rankdir.RankDir::TB,
  )
  for name in edge_vnode_chain_for_test(info, internal) {
    @test.assert_eq(info.vnode_clusters.get(name), Some("cluster_inner"))
  }
  for name in edge_vnode_chain_for_test(info, between) {
    @test.assert_eq(info.vnode_clusters.get(name), Some("cluster_outer"))
  }
}

///|
test "build_edge_vnodes keeps cluster-local parallel chains at plain virtual width" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  let edge1 = graph.edge(a, b)
  let edge2 = graph.edge(a, b)
  ignore(edge2)

  let ranks : Map[String, Int] = Map([])
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge1)

  assert_eq(chain.length(), 2)
  let first = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(first.left_pt, 1.0)
  assert_eq(first.right_pt, 1.0)
  for name in chain {
    assert_eq(vnode_info.vnode_clusters.get(name), Some("cluster_0"))
  }
}

///|
test "build_edge_vnodes leaves cross-root-cluster chains unowned and at standard width" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let left = graph.subgraph(name="cluster_left")
  let right = graph.subgraph(name="cluster_right")
  let a = left.node("a")
  let b = right.node("b")
  let edge = graph.edge(a, b)

  let ranks : Map[String, Int] = Map([])
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let first = vnode_size_for_test(vnode_info, chain[0])

  assert_eq(first.left_pt, 11.0)
  assert_eq(first.right_pt, 11.0)
  for name in chain {
    assert_eq(vnode_info.vnode_clusters.get(name), Some(""))
  }
}

///|
test "build_edge_vnodes applies edge cluster key when endpoints stay at root" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let ranks : Map[String, Int] = Map([])
  ranks["a"] = 0
  ranks["b"] = 3

  let existing_names : Map[String, Bool] = Map([])
  existing_names["a"] = true
  existing_names["b"] = true

  let edge_cluster_keys : Map[String, String] = Map([])
  edge_cluster_keys[@edge_identity.edge_key(edge)] = "cluster_edge_owner"

  let vnode_info = build_edge_vnodes(
    [a, b],
    [edge],
    [],
    [],
    Map([]),
    ranks,
    20.0,
    @rankdir.RankDir::TB,
    existing_names,
    edge_cluster_keys,
    Map([]),
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)

  assert_eq(chain, [
    "\{@edge_identity.EDGE_VNODE_PREFIX}0_1",
    "\{@edge_identity.EDGE_VNODE_PREFIX}0_2",
  ])
  for name in chain {
    assert_eq(vnode_info.vnode_clusters.get(name), Some("cluster_edge_owner"))
  }
}
