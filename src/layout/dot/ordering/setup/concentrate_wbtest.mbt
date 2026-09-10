// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "concentrate absorbs the right virtual chain sharing a head port" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let tail = graph.node("tail")
  let head = graph.node("head")
  let in_port : @cgraph.Port = { name: Some("In"), compass: None, }
  let normal = graph.edge(
    tail,
    head,
    tail_port={ name: Some("Normal"), compass: None, },
    head_port=in_port,
  )
  let target = graph.edge(
    tail,
    head,
    tail_port={ name: Some("Target"), compass: None, },
    head_port=in_port,
  )
  let ranks : Map[String, Int] = { "tail": 0, "head": 3 }
  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let normal_chain = edge_vnode_chain_for_test(vnode_info, normal)
  let target_chain = edge_vnode_chain_for_test(vnode_info, target)
  let ordered_groups : Map[Int, Array[String]] = {
    1: [normal_chain[0], target_chain[0]],
    2: [normal_chain[1], target_chain[1]],
  }

  let concentrated = concentrate_vnode_data(
    graph,
    [normal, target],
    ranks,
    vnode_info,
    ordered_groups,
  )

  assert_eq(normal.get_attr("_concentrated_absorbed"), Some("false"))
  assert_eq(target.get_attr("_concentrated_absorbed"), Some("true"))
  assert_eq(
    edge_vnode_chain_for_test(concentrated.vnode_info, normal),
    edge_vnode_chain_for_test(concentrated.vnode_info, target),
  )
  assert_eq(concentrated.vnode_info.vnode_ranks.length(), 2)
}
