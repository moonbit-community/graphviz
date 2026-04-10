// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn zero_cluster_label_padding(
  graph : @cgraph.Graph,
  rankdir : @rankdir.RankDir,
) -> @cluster_geometry.ClusterLabelPadding {
  ignore(graph)
  ignore(rankdir)
  { top: 0.0, bottom: 0.0 }
}

///|
fn build_long_edge_rank_heights_input(
  rankdir : @rankdir.RankDir,
  has_label : Bool,
  metrics : EdgeMidLabelMetrics?,
) -> RankHeightsInput {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  ignore(graph.node("b"))
  let c = graph.node("c")
  let edge = graph.edge(a, c)
  if has_label {
    edge.set_attr("label", "mid")
  }

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1
  ranks["c"] = 2

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a"]
  groups[1] = ["b"]
  groups[2] = ["c"]

  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.node_size_from_points(12.0, 10.0)
  sizes["b"] = @node_primitives.node_size_from_points(12.0, 8.0)
  sizes["c"] = @node_primitives.node_size_from_points(12.0, 12.0)

  let edge_mid_label_metrics_for = (target : @cgraph.Edge) => {
    ignore(target)
    metrics
  }

  make_rank_heights_input(
    graph,
    [edge],
    ranks,
    groups,
    [0, 1, 2],
    [0, 1, 2],
    sizes,
    Map::new(),
    rankdir,
    0.4,
    0.75,
    has_label,
    20.0,
    edge_mid_label_metrics_for,
    zero_cluster_label_padding,
  )
}

///|
fn rank_parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 {
    @numeric.parse_double_or(parts[0], 0.0)
  } else {
    0.0
  }
  let y = if parts.length() > 1 {
    @numeric.parse_double_or(parts[1], 0.0)
  } else {
    0.0
  }
  { x, y }
}

///|
fn rank_layout_node_pos(
  graph : @cgraph.Graph,
  name : String,
) -> @geom.Point raise {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => rank_parse_point(value)
        None => fail("missing pos for node \{name}")
      }
    None => fail("missing node \{name}")
  }
}

///|
test "compute_rank_heights uses vnode height on intermediate long-edge ranks" {
  let heights = compute_rank_heights(
    build_long_edge_rank_heights_input(@rankdir.RankDir::TB, false, None),
  )

  assert_eq(heights.rank_pht.get(0), Some(5.0))
  assert_eq(heights.rank_pht.get(1), Some(10.0))
  assert_eq(heights.rank_pht.get(2), Some(6.0))
  assert_eq(heights.rank_ht1.get(1), Some(10.0))
  assert_eq(heights.rank_ht2.get(1), Some(10.0))
  assert_eq(heights.nodesep_pt, 29.0)
  assert_eq(heights.ranksep_pt, 54.0)
}

///|
test "compute_rank_heights uses label midpoint height and halves rank separation in TB" {
  let heights = compute_rank_heights(
    build_long_edge_rank_heights_input(
      @rankdir.RankDir::TB,
      true,
      Some(make_edge_mid_label_metrics(22.0, 30.0)),
    ),
  )

  assert_eq(heights.rank_pht.get(1), Some(15.0))
  assert_eq(heights.rank_ht1.get(1), Some(15.0))
  assert_eq(heights.rank_ht2.get(1), Some(15.0))
  assert_eq(heights.ranksep_pt, 27.0)
}

///|
test "compute_rank_heights uses label width as midpoint height in LR" {
  let heights = compute_rank_heights(
    build_long_edge_rank_heights_input(
      @rankdir.RankDir::LR,
      true,
      Some(make_edge_mid_label_metrics(22.0, 30.0)),
    ),
  )

  assert_eq(heights.rank_pht.get(1), Some(11.0))
  assert_eq(heights.rank_ht1.get(1), Some(11.0))
  assert_eq(heights.rank_ht2.get(1), Some(11.0))
  assert_eq(heights.ranksep_pt, 27.0)
}

///|
test "edge labels expand rank spacing" {
  let with_label = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; a -> b [label=\"EdgeLabel\"]; }",
  )
  let layout_label = @layout_dot.layout_dot(with_label)
  layout_label.apply()
  let pos_a = rank_layout_node_pos(with_label, "a")
  let pos_b = rank_layout_node_pos(with_label, "b")
  let dist_label = Double::abs(pos_a.y - pos_b.y)

  let without_label = @dot_parser.parse_dot(
    "digraph { node [shape=box,width=1,height=1,label=\"\"]; a -> b; }",
  )
  let layout_plain = @layout_dot.layout_dot(without_label)
  layout_plain.apply()
  let pos_plain_a = rank_layout_node_pos(without_label, "a")
  let pos_plain_b = rank_layout_node_pos(without_label, "b")
  let dist_plain = Double::abs(pos_plain_a.y - pos_plain_b.y)

  guard dist_label > dist_plain else {
    fail("expected labeled edge to increase rank spacing")
  }
}
