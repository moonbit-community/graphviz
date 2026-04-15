// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "recover_slack_key_for_edge uses parallel keys only for unlabeled undirected edges" {
  let undir = @cgraph.Graph::new(@cgraph.GraphKind::Undirected, strict=false)
  let undir_edge = undir.edge(undir.node("a"), undir.node("b"))

  let directed = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let labeled_edge = directed.edge(directed.node("a"), directed.node("b"))
  labeled_edge.set_attr("label", "mid")

  let expected_parallel_key = "parallel|" +
    @edge_ops.edge_parallel_key("a", "b", None, None)
  let expected_vnode_key = "vnode|" +
    @edge_identity.edge_vnode_key(labeled_edge)

  assert_eq(recover_slack_key_for_edge(undir_edge), expected_parallel_key)
  assert_eq(recover_slack_key_for_edge(labeled_edge), expected_vnode_key)
}

///|
test "recover plan picks center-most edge but routing plan pins multi-edge groups to first ordered edge" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_a = graph.edge(a, b)
  let edge_b = graph.edge(a, b)
  let edge_c = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[edge_a.id()] = build_route_base(edge_a, parallel_offset=2.0)
  base_cache[edge_b.id()] = build_route_base(edge_b, parallel_offset=-1.0)
  base_cache[edge_c.id()] = build_route_base(edge_c, parallel_offset=1.0)

  let selected = recover_regular_selection([edge_a, edge_b, edge_c], base_cache)
  let recover_key = recover_slack_key_for_edge(edge_a)
  let group_key = @edge_identity.edge_vnode_key(edge_a)
  assert_eq(selected.get(recover_key), Some(edge_c.id()))

  let plan = build_regular_recover_routing_plan(
    [edge_a, edge_b, edge_c],
    base_cache,
  )
  assert_eq(
    plan.regular_parallel_groups
    .get(group_key)
    .map(fn(edges) { edges.map(fn(edge) { edge.id() }) }),
    Some([edge_a.id(), edge_b.id(), edge_c.id()]),
  )
  assert_eq(
    plan.recover_edge_id_for_routing.get(recover_key),
    Some(edge_a.id()),
  )
}
