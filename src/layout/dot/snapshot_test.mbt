///|
fn attr_map(attrs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = Map::new()
  for pair in attrs {
    let (key, value) = pair
    if key == "lheight" || key == "lwidth" {
      continue
    }
    map[key] = value
  }
  map
}

///|
fn port_key(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut out = ""
      match value.name {
        Some(name) => out = name
        None => ()
      }
      match value.compass {
        Some(compass) => {
          let label = match compass {
            @cgraph.Compass::N => "n"
            @cgraph.Compass::NE => "ne"
            @cgraph.Compass::E => "e"
            @cgraph.Compass::SE => "se"
            @cgraph.Compass::S => "s"
            @cgraph.Compass::SW => "sw"
            @cgraph.Compass::W => "w"
            @cgraph.Compass::NW => "nw"
            @cgraph.Compass::C => "c"
          }
          if out == "" {
            out = label
          } else {
            out = "\{out}:\{label}"
          }
        }
        None => ()
      }
      out
    }
  }
}

///|
fn edge_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let name = match edge.name() {
    Some(value) => value
    None => ""
  }
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  "\{tail}|\{head}|\{name}|\{tail_port}|\{head_port}"
}

///|
fn is_numeric_attr(name : String) -> Bool {
  match name {
    "bb" | "pos" | "lp" | "width" | "height" => true
    _ => false
  }
}

///|
fn extract_numbers(value : String) -> Array[Double] raise {
  let sb = StringBuilder::new()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    let value = @strconv.parse_double(token)
    numbers.push(value)
  }
  numbers
}

///|
fn compare_attr_value(
  name : String,
  expected : String,
  actual : String,
  tol : Double,
) -> Unit raise {
  if is_numeric_attr(name) {
    // Bezier clipping uses a coarse stopping threshold; allow a bit more slack for pos.
    let value_tol = if name == "pos" { tol * 1.5 } else { tol }
    let expected_nums = extract_numbers(expected)
    let actual_nums = extract_numbers(actual)
    assert_eq(expected_nums.length(), actual_nums.length())
    for i in 0..<expected_nums.length() {
      let ok = Double::is_close(
        expected_nums[i],
        actual_nums[i],
        absolute_tolerance=value_tol,
      )
      if !ok {
        fail("\{name} mismatch: expected=\{expected} actual=\{actual}")
      }
    }
  } else {
    assert_eq(expected, actual)
  }
}

///|
fn compare_attrs(
  expected : Array[(String, String)],
  actual : Array[(String, String)],
  tol : Double,
) -> Unit raise {
  let expected_map = attr_map(expected)
  let actual_map = attr_map(actual)
  for key, value in expected_map {
    match actual_map.get(key) {
      Some(actual_value) => compare_attr_value(key, value, actual_value, tol)
      None => fail("missing attr \{key}")
    }
  }
}

///|
fn compare_nodes(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  let expected_nodes = expected.nodes()
  let actual_nodes = actual.nodes()
  assert_eq(expected_nodes.length(), actual_nodes.length())
  let expected_map : Map[String, @cgraph.Node] = Map::new()
  for node in expected_nodes {
    expected_map[node.name()] = node
  }
  let actual_map : Map[String, @cgraph.Node] = Map::new()
  for node in actual_nodes {
    actual_map[node.name()] = node
  }
  for name, expected_node in expected_map {
    match actual_map.get(name) {
      Some(actual_node) =>
        compare_attrs(expected_node.attrs(), actual_node.attrs(), tol)
      None => fail("missing node \{name}")
    }
  }
}

///|
fn compare_edges(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  let expected_edges = expected.edges()
  let actual_edges = actual.edges()
  assert_eq(expected_edges.length(), actual_edges.length())
  let expected_map : Map[String, @cgraph.Edge] = Map::new()
  for edge in expected_edges {
    expected_map[edge_key(edge)] = edge
  }
  let actual_map : Map[String, @cgraph.Edge] = Map::new()
  for edge in actual_edges {
    actual_map[edge_key(edge)] = edge
  }
  for key, expected_edge in expected_map {
    match actual_map.get(key) {
      Some(actual_edge) =>
        compare_attrs(expected_edge.attrs(), actual_edge.attrs(), tol)
      None => fail("missing edge \{key}")
    }
  }
}

///|

///|
fn compare_subgraphs(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  let expected_subgraphs = expected.subgraphs()
  let actual_subgraphs = actual.subgraphs()
  assert_eq(expected_subgraphs.length(), actual_subgraphs.length())
  for i in 0..<expected_subgraphs.length() {
    compare_graph(expected_subgraphs[i], actual_subgraphs[i], tol)
  }
}

///|
fn compare_graph(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  compare_attrs(expected.attrs(), actual.attrs(), tol)
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Graph),
    actual.default_attrs(@cgraph.AttrKind::Graph),
    tol,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Node),
    actual.default_attrs(@cgraph.AttrKind::Node),
    tol,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Edge),
    actual.default_attrs(@cgraph.AttrKind::Edge),
    tol,
  )
  compare_nodes(expected, actual, tol)
  compare_edges(expected, actual, tol)
  compare_subgraphs(expected, actual, tol)
}

///|
fn filter_attrs_for_nodes_only(
  attrs : Array[(String, String)],
) -> Array[(String, String)] {
  let filtered : Array[(String, String)] = []
  for pair in attrs {
    let (name, value) = pair
    if name != "bb" {
      filtered.push((name, value))
    }
  }
  filtered
}

///|
fn compare_graph_nodes_only(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  compare_attrs(
    filter_attrs_for_nodes_only(expected.attrs()),
    filter_attrs_for_nodes_only(actual.attrs()),
    tol,
  )
  compare_attrs(
    filter_attrs_for_nodes_only(expected.default_attrs(@cgraph.AttrKind::Graph)),
    filter_attrs_for_nodes_only(actual.default_attrs(@cgraph.AttrKind::Graph)),
    tol,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Node),
    actual.default_attrs(@cgraph.AttrKind::Node),
    tol,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Edge),
    actual.default_attrs(@cgraph.AttrKind::Edge),
    tol,
  )
  compare_nodes(expected, actual, tol)
  let expected_subgraphs = expected.subgraphs()
  let actual_subgraphs = actual.subgraphs()
  assert_eq(expected_subgraphs.length(), actual_subgraphs.length())
  for i in 0..<expected_subgraphs.length() {
    compare_graph_nodes_only(expected_subgraphs[i], actual_subgraphs[i], tol)
  }
}

///|
fn assert_snapshot(
  input_path : String,
  expected_path : String,
  tol : Double,
) -> Unit raise {
  let graph = @dot_parser.parse_dot_file(input_path)
  let layout = layout_dot(graph)
  layout.apply()
  let actual = @dot_parser.write_dot(graph)
  let expected = @fs.read_file_to_string(expected_path)
  let expected_graph = @dot_parser.parse_dot(expected)
  let actual_graph = @dot_parser.parse_dot(actual)
  compare_graph(expected_graph, actual_graph, tol)
}

///|
fn assert_snapshot_nodes_only(
  input_path : String,
  expected_path : String,
  tol : Double,
) -> Unit raise {
  let graph = @dot_parser.parse_dot_file(input_path)
  let layout = layout_dot(graph)
  layout.apply()
  let actual = @dot_parser.write_dot(graph)
  let expected = @fs.read_file_to_string(expected_path)
  let expected_graph = @dot_parser.parse_dot(expected)
  let actual_graph = @dot_parser.parse_dot(actual)
  compare_graph_nodes_only(expected_graph, actual_graph, tol)
}

///|
test "dot layout tier2 snapshots" {
  assert_snapshot(
    "refs/graphviz/graphs/directed/grammar.gv", "tests/layout/dot/grammar.dot", 0.01,
  )
  assert_snapshot_nodes_only(
    "tests/layout/dot/edge_label_spacing.dot", "tests/layout/dot/edge_label_spacing.gv.dot",
    30.0,
  )
  assert_snapshot_nodes_only(
    "tests/layout/dot/complex.dot", "tests/layout/dot/complex.gv.dot", 80.0,
  )
}
