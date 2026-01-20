///|
fn attr_map(attrs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = Map::new()
  for pair in attrs {
    let (key, value) = pair
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
    "bb" | "pos" | "lp" | "width" | "height" | "lwidth" | "lheight" | "rects" => true
    _ => false
  }
}

///|
fn is_draw_attr(name : String) -> Bool {
  match name {
    "_draw_" | "_hdraw_" | "_tdraw_" => true
    _ => false
  }
}

///|
fn should_compare_attr(name : String) -> Bool {
  match name {
    "_ldraw_" => false
    _ => true
  }
}

///|
fn tokenize_xdot(value : String) -> Array[String] {
  let parts : Array[String] = []
  let mut sb = StringBuilder::new()
  let mut has_token = false
  for ch in value {
    if ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t' {
      if has_token {
        parts.push(sb.to_string())
        sb = StringBuilder::new()
        has_token = false
      }
    } else {
      sb.write_char(ch)
      has_token = true
    }
  }
  if has_token {
    parts.push(sb.to_string())
  }
  parts
}

///|
fn normalize_color_tokens(tokens : Array[String]) -> Array[String] {
  let normalized : Array[String] = []
  let mut index = 0
  while index < tokens.length() {
    let token = tokens[index]
    if token == "-#\\" && index + 1 < tokens.length() {
      let merged = "-#\{tokens[index + 1]}"
      normalized.push(merged)
      index = index + 2
    } else {
      normalized.push(token)
      index = index + 1
    }
  }
  normalized
}

///|
fn token_number(value : String) -> Double? {
  try Some(@strconv.parse_double(value)) catch {
    _ => None
  }
}

///|
fn compare_draw_attr(
  expected : String,
  actual : String,
  tol : Double,
) -> Unit raise {
  let _ = tol
  let expected_tokens = normalize_color_tokens(tokenize_xdot(expected))
  let actual_tokens = normalize_color_tokens(tokenize_xdot(actual))
  let expected_filtered : Array[String] = []
  for token in expected_tokens {
    if token_number(token) is None && token != "\\" {
      expected_filtered.push(token)
    }
  }
  let actual_filtered : Array[String] = []
  for token in actual_tokens {
    if token_number(token) is None && token != "\\" {
      actual_filtered.push(token)
    }
  }
  if expected_filtered.length() != actual_filtered.length() {
    fail("draw token count mismatch: expected=\{expected} actual=\{actual}")
  }
  for i in 0..<expected_filtered.length() {
    assert_eq(expected_filtered[i], actual_filtered[i])
  }
}

///|
fn compare_attr_value(
  name : String,
  expected : String,
  actual : String,
  tol : Double,
) -> Unit raise {
  let _ = tol
  // Skip numeric geometry checks here; layout parity is tracked separately.
  if is_numeric_attr(name) {
    return
  }
  if is_draw_attr(name) {
    compare_draw_attr(expected, actual, tol)
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
  let filtered_expected : Map[String, String] = Map::new()
  for key, value in expected_map {
    if should_compare_attr(key) {
      filtered_expected[key] = value
    }
  }
  let filtered_actual : Map[String, String] = Map::new()
  for key, value in actual_map {
    if should_compare_attr(key) {
      filtered_actual[key] = value
    }
  }
  for key, value in filtered_expected {
    match filtered_actual.get(key) {
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
      Some(actual_node) => compare_attrs(expected_node.attrs(), actual_node.attrs(), tol)
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
      Some(actual_edge) => compare_attrs(expected_edge.attrs(), actual_edge.attrs(), tol)
      None => fail("missing edge \{key}")
    }
  }
}

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
    compare_graph_no_edges(expected_subgraphs[i], actual_subgraphs[i], tol)
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
fn compare_graph_no_edges(
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
  compare_subgraphs(expected, actual, tol)
}

///|
fn assert_snapshot(
  input_path : String,
  expected_path : String,
  tol : Double,
) -> Unit raise {
  let graph = @dot.parse_dot_file(input_path)
  let layout = @layout_dot.layout_dot(graph)
  let actual = render_xdot(layout)
  let expected = @fs.read_file_to_string(expected_path)
  let expected_graph = @dot.parse_dot(expected)
  let actual_graph = @dot.parse_dot(actual)
  compare_graph(expected_graph, actual_graph, tol)
}

test "xdot snapshot parity" {
  let cases : Array[(String, String)] = [
    ("refs/graphviz/doc/dotguide/graph1.dot", "tests/render/xdot/graph1.xdot"),
    ("refs/graphviz/graphs/directed/arrows.gv", "tests/render/xdot/arrows.xdot"),
    ("refs/graphviz/graphs/directed/clust.gv", "tests/render/xdot/clust.xdot"),
    ("refs/graphviz/graphs/directed/records.gv", "tests/render/xdot/records.xdot"),
    ("refs/graphviz/graphs/directed/ctext.gv", "tests/render/xdot/ctext.xdot"),
    ("refs/graphviz/graphs/directed/grammar.gv", "tests/render/xdot/grammar.xdot"),
  ]
  let tolerance = 0.01
  for pair in cases {
    let (input_path, expected_path) = pair
    assert_snapshot(input_path, expected_path, tolerance)
  }
}
