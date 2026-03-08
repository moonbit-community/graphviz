///|
fn zero_cluster_label_padding(
  graph : @cgraph.Graph,
  rankdir : @rankdir.RankDir,
) -> @clustering.ClusterLabelPadding {
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
test "acyclic_edge_directions_for_names reverses the back edge of a cycle" {
  let directions = acyclic_edge_directions_for_names(
    ["a", "b", "c"],
    ["a", "b", "c", "b"],
    ["b", "c", "a", "b"],
    [true, true, true, true],
  )

  assert_eq(directions.tail, ["a", "b", "a", "b"])
  assert_eq(directions.head, ["b", "c", "c", "b"])
  assert_eq(directions.reversed, [false, false, true, false])
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
test "compute_ranks_directed_base merges parallel constraints and normalizes components independently" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")

  let edge_ab_lo = graph.edge(a, b)
  edge_ab_lo.set_attr("minlen", "1")
  edge_ab_lo.set_attr("weight", "2")
  let edge_ab_hi = graph.edge(a, b, name="parallel")
  edge_ab_hi.set_attr("minlen", "3")
  edge_ab_hi.set_attr("weight", "5")
  let edge_xy = graph.edge(x, y)
  edge_xy.set_attr("minlen", "1")
  edge_xy.set_attr("weight", "1")

  let ranks = compute_ranks_directed_base(
    graph,
    [a, b, x, y],
    [edge_ab_lo, edge_ab_hi, edge_xy],
    false,
    ["a", "a", "x"],
    ["b", "b", "y"],
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(3))
  assert_eq(ranks.get("x"), Some(0))
  assert_eq(ranks.get("y"), Some(1))
}

///|
test "compute_ranks_directed_base keeps rank=same nodes in one simplex component" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")

  let same = graph.subgraph(name="same")
  same.set_attr("rank", "same")
  ignore(same.node("b"))
  ignore(same.node("x"))

  let edge_ab = graph.edge(a, b)
  edge_ab.set_attr("minlen", "1")
  let edge_xy = graph.edge(x, y)
  edge_xy.set_attr("minlen", "1")

  let ranks = compute_ranks_directed_base(
    graph,
    [a, b, x, y],
    [edge_ab, edge_xy],
    false,
    ["a", "x"],
    ["b", "y"],
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
  assert_eq(ranks.get("x"), Some(1))
  assert_eq(ranks.get("y"), Some(2))
}

////|

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
