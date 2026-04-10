// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_edge_vnodes widens shared chains for parallel unlabeled edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge1 = graph.edge(a, b)
  let edge2 = graph.edge(a, b)
  ignore(edge2)

  let ranks : Map[String, Int] = Map::new()
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
  let second = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(first.left_pt, 21.0)
  assert_eq(first.right_pt, 21.0)
  assert_eq(second.left_pt, 21.0)
  assert_eq(second.right_pt, 21.0)
}

///|
test "build_edge_vnodes reuses the same chain for reverse unlabeled duplicates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let reverse = graph.edge(b, a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let forward_chain = edge_vnode_chain_for_test(vnode_info, forward)
  let reverse_chain = edge_vnode_chain_for_test(vnode_info, reverse)

  assert_eq(reverse_chain, forward_chain)
  let first = vnode_size_for_test(vnode_info, forward_chain[0])
  assert_eq(first.left_pt, 21.0)
  assert_eq(first.right_pt, 21.0)
}

///|
test "build_edge_vnodes respects explicit out-order when reverse duplicate creates chain first" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let reverse = graph.edge(b, a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let existing_names : Map[String, Bool] = Map::new()
  existing_names["a"] = true
  existing_names["b"] = true

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["b"] = [1]
  edge_out_order["a"] = [0]

  let vnode_info = build_edge_vnodes(
    [b, a],
    [forward, reverse],
    [],
    [],
    edge_out_order,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
    existing_names,
    Map::new(),
    Map::new(),
  )
  let forward_chain = edge_vnode_chain_for_test(vnode_info, forward)
  let reverse_chain = edge_vnode_chain_for_test(vnode_info, reverse)

  assert_eq(forward_chain, [
    "\{@edge_identity.EDGE_VNODE_PREFIX}1_1",
    "\{@edge_identity.EDGE_VNODE_PREFIX}1_2",
  ])
  assert_eq(reverse_chain, forward_chain)
  let first = vnode_size_for_test(vnode_info, forward_chain[0])
  assert_eq(first.left_pt, 21.0)
  assert_eq(first.right_pt, 21.0)
}
