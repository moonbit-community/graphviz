///|
fn assert_double_close(
  actual : Double,
  expected : Double,
  eps : Double,
) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=eps)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
fn edge_at(graph : @cgraph.Graph, index : Int) -> @cgraph.Edge raise {
  let edges = graph.edges()
  guard index >= 0 && index < edges.length() else {
    fail("expected edge at index \{index}")
  }
  edges[index]
}

///|
test "base parse helpers extract and clamp doubles" {
  assert_double_close(@numeric.parse_double_or("12.5", 0.0), 12.5, 0.000001)
  assert_double_close(@numeric.parse_double_or("oops", 3.5), 3.5, 0.000001)

  assert_double_close(
    @numeric.parse_first_double("ranksep=1.75 equally", 0.0),
    1.75,
    0.000001,
  )
  assert_double_close(
    @numeric.parse_first_double("equally", 2.25),
    2.25,
    0.000001,
  )

  assert_eq(@numeric.parse_first_double_optional(" +2.5 equally"), Some(2.5))
  assert_eq(@numeric.parse_first_double_optional("equally"), None)

  assert_double_close(@numeric.parse_attr_double("-0.5", 1.0, 0.02), 0.02, 0.000001)
  assert_double_close(@numeric.parse_attr_double("2.0", 1.0, 0.02), 2.0, 0.000001)
  assert_double_close(
    @numeric.parse_attr_double("equally", 1.0, 0.02),
    1.0,
    0.000001,
  )
}

///|
test "base rankdir and splines parsers accept graphviz aliases" {
  assert_eq(@dot_shared.parse_rankdir("TB"), Some(RankDir::TB))
  assert_eq(@dot_shared.parse_rankdir("bt"), Some(RankDir::BT))
  assert_eq(@dot_shared.parse_rankdir("Lr"), Some(RankDir::LR))
  assert_eq(@dot_shared.parse_rankdir("rl"), Some(RankDir::RL))
  assert_eq(@dot_shared.parse_rankdir("diag"), None)

  assert_eq(@input_stage.parse_splines("true"), Some(SplinesMode::Spline))
  assert_eq(@input_stage.parse_splines("line"), Some(SplinesMode::Polyline))
  assert_eq(@input_stage.parse_splines(""), Some(SplinesMode::None))
  assert_eq(@input_stage.parse_splines("ortho"), Some(SplinesMode::Ortho))
  assert_eq(@input_stage.parse_splines("curved"), Some(SplinesMode::Curved))
  assert_eq(@input_stage.parse_splines("bogus"), None)
}

///|
test "graph_rankdir walks parent chain" {
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=RL; subgraph cluster_outer { subgraph cluster_inner { a -> b } } }",
  )
  assert_eq(@dot_shared.graph_rankdir(graph), RankDir::RL)

  let outer = graph.subgraphs()[0]
  let inner = outer.subgraphs()[0]
  assert_eq(@dot_shared.graph_rankdir(outer), RankDir::RL)
  assert_eq(@dot_shared.graph_rankdir(inner), RankDir::RL)

  let no_rankdir = @dot_parser.parse_dot("digraph { a -> b }")
  assert_eq(@dot_shared.graph_rankdir(no_rankdir), RankDir::TB)
}

///|
test "base edge dir parser" {
  guard @edge_semantics.parse_edge_dir("forward") is Some(@edge_semantics.EdgeDir::Forward) else {
    fail("expected dir=forward")
  }
  guard @edge_semantics.parse_edge_dir("b") is Some(@edge_semantics.EdgeDir::Back) else {
    fail("expected dir=b to map to Back")
  }
  guard @edge_semantics.parse_edge_dir("both") is Some(@edge_semantics.EdgeDir::Both) else {
    fail("expected dir=both")
  }
  guard @edge_semantics.parse_edge_dir("none") is Some(@edge_semantics.EdgeDir::None) else {
    fail("expected dir=none")
  }
  guard @edge_semantics.parse_edge_dir("invalid") is None else {
    fail("expected invalid dir to return None")
  }
}

///|
test "edge_dir_for uses graph kind and defaults" {
  let directed = @dot_parser.parse_dot(
    "digraph { a -> b [dir=back]; c -> d [dir=invalid]; e -> f }",
  )
  guard @edge_semantics.edge_dir_for(edge_at(directed, 0), directed.kind()) is @edge_semantics.EdgeDir::Back else {
    fail("expected first edge to be Back")
  }
  guard @edge_semantics.edge_dir_for(edge_at(directed, 1), directed.kind()) is @edge_semantics.EdgeDir::Forward else {
    fail("expected invalid dir attr to default Forward")
  }
  guard @edge_semantics.edge_dir_for(edge_at(directed, 2), directed.kind()) is @edge_semantics.EdgeDir::Forward else {
    fail("expected missing dir attr to default Forward")
  }

  let undirected = @dot_parser.parse_dot("graph { a -- b [dir=both] }")
  guard @edge_semantics.edge_dir_for(edge_at(undirected, 0), undirected.kind()) is @edge_semantics.EdgeDir::None else {
    fail("expected undirected edges to use EdgeDir::None")
  }
}

///|
test "dot format helpers keep graphviz-like numeric strings" {
  assert_eq(@dot_shared.trim_trailing_zeros("12.3400"), "12.34")
  assert_eq(@dot_shared.trim_trailing_zeros("42"), "42")

  assert_eq(@dot_shared.format_fixed(12.345, 2), "12.34")
  assert_eq(@dot_shared.format_fixed(-12.345, 2), "-12.34")
  assert_eq(@dot_shared.format_fixed_trim(2.5000, 4), "2.5")

  assert_double_close(@dot_shared.round_to(1.23456, 3), 1.235, 0.000001)

  assert_eq(@dot_shared.format_float(0.0), "0")
  assert_eq(@dot_shared.format_float(12.34567), "12.346")
  assert_eq(@dot_shared.format_float(123456.0), "1.2346e+05")
  assert_eq(@dot_shared.format_float(0.0000123456), "1.2346e-05")
  assert_eq(@dot_shared.format_float(-0.0000123456), "-1.2346e-05")

  assert_eq(@dot_shared.format_dim(12.0), "12")
  let point : @geom.Point = { x: 12.5, y: -0.25 }
  assert_eq(@dot_shared.format_point(point), "12.5,-0.25")

  let rect0 : @geom.Rect = { llx: 0.0, lly: 1.25, urx: 10.0, ury: 20.5 }
  let rect1 : @geom.Rect = { llx: -1.0, lly: -2.0, urx: 3.0, ury: 4.0 }
  assert_eq(@dot_shared.format_rect(rect0), "0,1.25,10,20.5")
  assert_eq(@dot_shared.format_rects([rect0, rect1]), "0,1.25,10,20.5 -1,-2,3,4")
}
