// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_edge_vnodes places the LR label vnode at midpoint rank and swaps label dimensions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 4

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::LR,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  assert_eq(chain.length(), 3)
  assert_eq(vnode_info.vnode_ranks.get(chain[0]), Some(1))
  assert_eq(vnode_info.vnode_ranks.get(chain[1]), Some(2))
  assert_eq(vnode_info.vnode_ranks.get(chain[2]), Some(3))

  let plain = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(plain.left_pt, 11.0)
  assert_eq(plain.right_pt, 11.0)
  assert_eq(plain.height_pt, @node_primitives.VNODE_HEIGHT_PT)

  let label = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(label.left_pt, 20.0)
  assert_eq(label.right_pt, metrics.height)
  assert_eq(label.height_pt, metrics.width)
}

///|
test "build_edge_vnodes places the TB label vnode at midpoint rank with unflipped dimensions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "Very Long Edge Label")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 5

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  assert_eq(chain.length(), 4)
  assert_eq(vnode_info.vnode_ranks.get(chain[0]), Some(1))
  assert_eq(vnode_info.vnode_ranks.get(chain[1]), Some(2))
  assert_eq(vnode_info.vnode_ranks.get(chain[2]), Some(3))
  assert_eq(vnode_info.vnode_ranks.get(chain[3]), Some(4))

  let plain = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(plain.left_pt, 11.0)
  assert_eq(plain.right_pt, 11.0)
  assert_eq(plain.height_pt, @node_primitives.VNODE_HEIGHT_PT)

  let label = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(label.left_pt, 20.0)
  assert_eq(label.right_pt, metrics.width)
  assert_eq(label.height_pt, metrics.height)
}
