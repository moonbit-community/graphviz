// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "concentrated auxiliary copies retain their installed output slots" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let a = graph.subgraph(name="cluster_a").node("a")
  let b = graph.node("b")
  let first = graph.edge(a, b)
  let second = graph.edge(a, b)
  @test.assert_eq(
    collect_parallel_remap_edge_ids([first, second], { "a": 0, "b": 1 }).length(),
    0,
  )
}

///|
test "retained concentrated main edges do not share parallel routes or remap slots" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let a = graph.node("a")
  let b = graph.node("b")
  let first = graph.edge(a, b)
  let second = graph.edge(a, b)
  let bases = Map([
    (first.id(), build_route_base(first)),
    (second.id(), build_route_base(second)),
  ])
  @test.assert_eq(collect_parallel_groups([first, second], bases).length(), 0)
  @test.assert_eq(
    collect_parallel_remap_edge_ids([first, second], { "a": 0, "b": 1 }).length(),
    0,
  )
}

///|
test "collect_parallel_reuse_siblings only expands from the first grouped edge with a bezier" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let regular_parallel_groups : Map[String, Array[@cgraph.Edge]] = Map([])
  regular_parallel_groups[@edge_identity.edge_vnode_key(edge_1)] = [
    edge_1, edge_2, edge_3,
  ]

  let leader_siblings = collect_parallel_reuse_siblings(
    edge_1,
    straight_bezier_points(),
    regular_parallel_groups,
    Map([]),
  )
  let follower_siblings = collect_parallel_reuse_siblings(
    edge_2,
    straight_bezier_points(),
    regular_parallel_groups,
    Map([]),
  )
  let empty_bezier_siblings = collect_parallel_reuse_siblings(
    edge_1,
    [],
    regular_parallel_groups,
    Map([]),
  )

  assert_eq(leader_siblings.map(fn(edge) { edge.id() }), [
    edge_2.id(),
    edge_3.id(),
  ])
  assert_eq(follower_siblings.length(), 0)
  assert_eq(empty_bezier_siblings.length(), 0)
  let concentrated_siblings = collect_parallel_reuse_siblings(
    edge_1,
    straight_bezier_points(),
    regular_parallel_groups,
    Map([(edge_2.id(), true), (edge_3.id(), true)]),
  )
  @test.assert_eq(concentrated_siblings.length(), 0)
  let partial_siblings = collect_parallel_reuse_siblings(
    edge_1,
    straight_bezier_points(),
    regular_parallel_groups,
    Map([(edge_2.id(), true)]),
  )
  @test.assert_eq(partial_siblings.map(edge => edge.id()), [edge_3.id()])
}

///|
test "apply_regular_parallel_reuse_layouts writes sibling layouts only when their bases exist" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let shared = @emit.edge_spline_result_for_bezier(
    spline_with_start_x(12.0),
    straight_bezier_points(),
    0.0,
    false,
  )
  let regular_layout : RegularSplineLayoutResult = {
    edge_layout: build_layout_edge(edge_1, 12.0),
    spline_result: shared,
  }
  let regular_parallel_groups : Map[String, Array[@cgraph.Edge]] = Map([])
  regular_parallel_groups[@edge_identity.edge_vnode_key(edge_1)] = [
    edge_1, edge_2, edge_3,
  ]
  let base_cache : Map[Int, EdgeRouteBase] = Map([])
  let edge_2_base = build_route_base(edge_2)
  base_cache[edge_2.id()] = edge_2_base
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map([])
  let callbacks : RoutingCallbacks = {
    recover_slack_vnodes_fn: _ => (),
    build_edge_layout_fn: layout_input => {
      build_layout_edge(layout_input.base.edge, layout_input.spline.points[0].x)
    },
    self_edge_label_height_fn: (_edge, _rankdir) => 0.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
    edge_port_label_pos_fn: _ => None,
  }
  let expected_layout = @emit.build_regular_bezier_layout(
    edge_2_base,
    shared,
    callbacks.build_edge_layout_fn,
  )

  apply_regular_parallel_reuse_layouts({
    edge: edge_1,
    regular_layout,
    regular_parallel_groups,
    base_cache,
    edges_out_by_id,
    callbacks,
    ignored_edge_ids: Map([]),
  })

  assert_eq(
    edges_out_by_id
    .get(edge_2.id())
    .map(fn(layout) { layout.splines[0].points[0].x }),
    Some(expected_layout.splines[0].points[0].x),
  )
  assert_true(edges_out_by_id.get(edge_3.id()) is None)

  // An ignored concentrated sibling must not acquire a reusable layout:
  // final parallel-slot remapping would otherwise overwrite the leader.
  let concentrated_output = Map([(edge_1.id(), regular_layout.edge_layout)])
  let ignored_edge_ids = Map([(edge_2.id(), true), (edge_3.id(), true)])
  apply_regular_parallel_reuse_layouts({
    edge: edge_1,
    regular_layout,
    regular_parallel_groups,
    base_cache,
    edges_out_by_id: concentrated_output,
    callbacks,
    ignored_edge_ids,
  })
  @test.assert_eq(concentrated_output.get(edge_2.id()) is None, true)
  let finalized = finalize_routed_edges({
    edges: [edge_1, edge_2, edge_3],
    ranks: { "a": 0, "b": 1 },
    edges_out_by_id: concentrated_output,
    edge_port_label_pos_fn: callbacks.edge_port_label_pos_fn,
    concentrated_ignored_edge_ids: ignored_edge_ids,
  })
  @test.assert_eq(finalized.length(), 1)
  @test.assert_eq(finalized[0].edge.id(), edge_1.id())
  @test.assert_eq(finalized[0].splines[0].points[0].x, 12.0)
}
