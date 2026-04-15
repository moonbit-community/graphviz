// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "non-adjacent flat edge injects a label vnode and splits constraints" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let c = graph.node("c")
  let b = graph.node("b")
  ignore(c)
  let edge = graph.edge(a, b)
  edge.set_attr("label", "non-adjacent")

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
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::TB,
    sizes,
    Map::new(),
    Map::new(),
    make_existing_names(["a", "b", "c"]),
    vnode_info,
    x_groups,
  )

  assert_eq(result.flat_label_ranks.length(), 1)
  assert_eq(result.flat_label_edges.length(), 2)

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
    [label_vnode],
  )

  let size = match vnode_info.vnode_sizes.get(label_vnode) {
    Some(value) => value
    None => fail("expected vnode size")
  }
  assert_eq(size.left_pt, metrics.width / 2.0)
  assert_eq(size.right_pt, metrics.width / 2.0)
  assert_eq(size.height_pt, metrics.height)

  let expected_minlen = @numeric.round_int(20.0 + 5.0 + metrics.width / 2.0)
  let left_edge = result.flat_label_edges[0]
  let right_edge = result.flat_label_edges[1]
  assert_eq(left_edge.tail, "a")
  assert_eq(left_edge.head, label_vnode)
  assert_eq(left_edge.minlen, expected_minlen)
  assert_eq(left_edge.weight, 1)
  assert_eq(right_edge.tail, label_vnode)
  assert_eq(right_edge.head, "b")
  assert_eq(right_edge.minlen, expected_minlen)
  assert_eq(right_edge.weight, 1)
}

///|
test "non-adjacent LR flat edge swaps label width and height for vnode sizing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let c = graph.node("c")
  let b = graph.node("b")
  ignore(c)
  let edge = graph.edge(a, b)
  edge.set_attr("label", "lr-non-adjacent")

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
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::LR,
    sizes,
    Map::new(),
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
  let size = match vnode_info.vnode_sizes.get(label_vnode) {
    Some(value) => value
    None => fail("expected vnode size")
  }

  assert_eq(size.left_pt, metrics.height / 2.0)
  assert_eq(size.right_pt, metrics.height / 2.0)
  assert_eq(size.height_pt, metrics.width)
}

///|
test "non-adjacent flat edge uses half-scale minlen when graph ordering is unset" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let c = graph.node("c")
  let b = graph.node("b")
  ignore(c)
  let edge = graph.edge(a, b)
  edge.set_attr("label", "default-ordering")

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
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  let result = build_flat_label_vnodes_for_positioning(
    [edge],
    ["a"],
    ["b"],
    ranks,
    ordered_groups,
    20.0,
    @rankdir.RankDir::TB,
    sizes,
    Map::new(),
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
  let expected_minlen = @numeric.round_int(10.0 + 5.0 + metrics.width / 2.0)
  assert_eq(result.flat_label_ranks.get(label_vnode), Some(-1))
  assert_eq(result.flat_label_edges.length(), 2)
  assert_eq(result.flat_label_edges[0].minlen, expected_minlen)
  assert_eq(result.flat_label_edges[1].minlen, expected_minlen)
}
