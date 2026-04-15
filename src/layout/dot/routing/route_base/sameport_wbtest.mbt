// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "collect_sameport_overrides propagates samehead anchors to unlabeled merge mates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge1 = graph.edge(a, b)
  let edge2 = graph.edge(a, b)
  let edge3 = graph.edge(a, b)
  edge1.set_attr("samehead", "g")
  edge2.set_attr("samehead", "g")

  let size = @node_primitives.node_size_from_points(20.0, 20.0)
  let overrides = collect_sameport_overrides({
    edges: [edge1, edge2, edge3],
    positions: {
      "a": @edge_spline.point(0.0, 0.0),
      "b": @edge_spline.point(100.0, 0.0),
    },
    sizes: { "a": size, "b": size },
    node_size_for_missing: _node => size,
    layout_rankdir: RankDir::TB,
    ranksep_pt: 18.0,
  })

  let anchor1 = match overrides.samehead_anchors.get(edge1.id()) {
    Some(value) => value
    None => fail("missing samehead anchor for edge1")
  }
  let anchor2 = match overrides.samehead_anchors.get(edge2.id()) {
    Some(value) => value
    None => fail("missing samehead anchor for edge2")
  }
  let anchor3 = match overrides.samehead_anchors.get(edge3.id()) {
    Some(value) => value
    None => fail("missing propagated samehead anchor for edge3")
  }

  assert_eq(anchor1, anchor2)
  assert_eq(anchor2, anchor3)
  assert_true(anchor1.x < 100.0)
  assert_eq(overrides.samehead_group_sizes.get(edge1.id()), Some(2))
  assert_eq(overrides.samehead_group_sizes.get(edge2.id()), Some(2))
  assert_eq(overrides.samehead_group_sizes.get(edge3.id()), Some(2))
  assert_eq(overrides.sametail_anchors.length(), 0)
}

///|
test "edge_sameport_orientation_info swaps head and tail anchors with swap_ends" {
  let samehead_anchors : Map[Int, @geom.Point] = {
    7: @edge_spline.point(10.0, 1.0),
  }
  let sametail_anchors : Map[Int, @geom.Point] = {
    7: @edge_spline.point(-4.0, 2.0),
  }
  let samehead_group_sizes : Map[Int, Int] = { 7: 5 }
  let sametail_group_sizes : Map[Int, Int] = { 7: 3 }
  let overrides = {
    samehead_anchors,
    sametail_anchors,
    samehead_group_sizes,
    sametail_group_sizes,
  }

  let normal = edge_sameport_orientation_info(7, overrides, false)
  assert_eq(normal.tail_anchor, Some(@edge_spline.point(-4.0, 2.0)))
  assert_eq(normal.head_anchor, Some(@edge_spline.point(10.0, 1.0)))
  assert_eq(normal.tail_group_size, 3)
  assert_eq(normal.head_group_size, 5)

  let swapped = edge_sameport_orientation_info(7, overrides, true)
  assert_eq(swapped.tail_anchor, Some(@edge_spline.point(10.0, 1.0)))
  assert_eq(swapped.head_anchor, Some(@edge_spline.point(-4.0, 2.0)))
  assert_eq(swapped.tail_group_size, 5)
  assert_eq(swapped.head_group_size, 3)
}

///|
test "edge_swap_ends_for_route_base keeps same-rank intercluster edges unswapped" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let should_not_swap = edge_swap_ends_for_route_base({
    edge,
    orig_tail_name: "a",
    orig_head_name: "b",
    ranks: { "a": 0, "b": 0 },
    order_index: { "a": 1, "b": 0 },
    node_local_cluster_key_fn: node => {
      if node.name() == "a" {
        "cluster_a"
      } else {
        "cluster_b"
      }
    },
  })
  assert_false(should_not_swap)

  let should_swap_within_cluster = edge_swap_ends_for_route_base({
    edge,
    orig_tail_name: "a",
    orig_head_name: "b",
    ranks: { "a": 0, "b": 0 },
    order_index: { "a": 1, "b": 0 },
    node_local_cluster_key_fn: _node => "cluster_a",
  })
  assert_true(should_swap_within_cluster)
}
