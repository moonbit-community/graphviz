///|
fn attr_map(attrs : Array[(String, String)]) -> Map[String, String] {
  let map : Map[String, String] = Map::new()
  for pair in attrs {
    let (key, value) = pair
    map[key] = value
  }
  map
}

fn is_numeric_attr(name : String) -> Bool {
  match name {
    "bb" | "pos" | "lp" | "width" | "height" | "lwidth" | "lheight" | "rects" => true
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
    let value_tol =
      if name == "pos" || name == "rects" || name == "bb" {
        let scaled = tol * 2.0
        if scaled > 0.5 { scaled } else { 0.5 }
      } else {
        tol
      }
    let tol_with_eps = value_tol + 0.000001
    let expected_nums = extract_numbers(expected)
    let actual_nums = extract_numbers(actual)
    if expected_nums.length() != actual_nums.length() {
      fail(
        "\{name} count mismatch: expected=\{expected} actual=\{actual}",
      )
    }
    for i in 0..<expected_nums.length() {
      let ok = Double::is_close(
        expected_nums[i],
        actual_nums[i],
        absolute_tolerance=tol_with_eps,
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
    expected_map[@edge_identity.edge_key(edge)] = edge
  }
  let actual_map : Map[String, @cgraph.Edge] = Map::new()
  for edge in actual_edges {
    actual_map[@edge_identity.edge_key(edge)] = edge
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
fn assert_snapshot(
  input_path : String,
  expected_path : String,
  tol : Double,
) -> Unit raise {
  ignore(tol)
  if @sys.get_env_var("DOT_SNAPSHOT_TRACE") is Some(_) {
    println("snapshot \{input_path}")
  }
  let graph = try {
    @dot_parser.parse_dot_file(input_path)
  } catch {
    err => {
      println("ERROR parsing \{input_path}: \{err}")
      raise err
    }
  }
  let layout = layout_dot(graph)
  layout.apply()
  let actual = @dot_parser.write_dot_bytes(graph)
  let expected = @fs.read_file_to_bytes(expected_path)
  if actual != expected {
    fail("dot snapshot mismatch: \{input_path}")
  }
}

///|
fn snapshot_input_path(case_name : String) -> String raise {
  let candidates : Array[String] = [
    "refs/graphviz/graphs/directed/\{case_name}.gv",
    "refs/graphviz/graphs/undirected/\{case_name}.gv",
    "tests/layout/dot/\{case_name}.dot",
    "refs/graphviz/doc/dotguide/\{case_name}.dot",
    "refs/graphviz/doc/infosrc/\{case_name}.dot",
    "refs/graphviz/doc/infosrc/\{case_name}.gv",
    "refs/graphviz/doc/neato/\{case_name}.dot",
    "refs/graphviz/contrib/prune/\{case_name}.gv",
    "refs/graphviz/contrib/dirgraph/\{case_name}.dot",
    "refs/graphviz/contrib/java-dot/\{case_name}.dot",
    "refs/graphviz/tests/\{case_name}.dot",
    "refs/graphviz/tests/graphs/\{case_name}.gv",
    "refs/graphviz/tests/share/\{case_name}.gv",
    "refs/graphviz/tests/windows/\{case_name}.gv",
    "refs/graphviz/tests/regression_tests/\{case_name}.gv",
    "refs/graphviz/tests/regression_tests/shapes/reference/\{case_name}.gv",
    "refs/graphviz/tests/linux.x86/\{case_name}.gv",
    "refs/graphviz/tests/nshare/\{case_name}.gv",
    "refs/graphviz/tests/linux.i386/\{case_name}.gv",
    "refs/graphviz/tests/macosx/\{case_name}.gv",
  ]
  for path in candidates {
    if @fs.path_exists(path) {
      return path
    }
  }
  fail("missing snapshot input for case \{case_name}")
}

///|
fn dot_fixture_path(fixture_dir : String, case_name : String) -> String {
  if case_name == "grammar" {
    "\{fixture_dir}/grammar.dot"
  } else {
    "\{fixture_dir}/\{case_name}.gv.dot"
  }
}

///|
fn load_case_names(manifest_path : String) -> Array[String] raise {
  let lines = @fs.read_file_to_string(manifest_path).split("\n")
  let names : Array[String] = []
  for raw in lines {
    let line = raw.trim(chars=" \t\r").to_string()
    if line == "" || line.has_prefix("#") {
      continue
    }
    names.push(line)
  }
  if names.length() == 0 {
    fail("empty snapshot case manifest: \{manifest_path}")
  }
  names
}

///|
fn dot_snapshot_cases(
  manifest_path : String,
  fixture_dir : String,
) -> Array[(String, String)] raise {
  let case_names = load_case_names(manifest_path)
  let seen : Map[String, Bool] = Map::new()
  let cases : Array[(String, String)] = []
  for case_name in case_names {
    if seen.get(case_name) is Some(_) {
      fail("duplicate snapshot case in manifest: \{case_name}")
    }
    seen[case_name] = true
    let fixture_path = dot_fixture_path(fixture_dir, case_name)
    if !@fs.path_exists(fixture_path) {
      fail("missing snapshot fixture: \{fixture_path}")
    }
    let input_path = snapshot_input_path(case_name)
    cases.push((input_path, fixture_path))
  }
  let extras : Array[String] = []
  for entry in @fs.read_dir(fixture_dir) {
    let case_name = if entry == "grammar.dot" {
      Some("grammar")
    } else if entry.has_suffix(".gv.dot") {
      Some(
        entry.unsafe_substring(
          start=0,
          end=entry.length() - ".gv.dot".length(),
        ),
      )
    } else {
      None
    }
    match case_name {
      Some(name) =>
        if seen.get(name) is None {
          extras.push("\{fixture_dir}/\{entry}")
        }
      None => ()
    }
  }
  if extras.length() > 0 {
    extras.sort_by_key(path => path)
    let details = extras.join(", ")
    fail("uncovered snapshot fixtures: \{details}")
  }
  cases
}

///|
fn full_parity_tests_enabled() -> Bool {
  @sys.get_env_var("DOT_RUN_FULL_PARITY_TESTS") is Some(_)
}

///|
test "compass ports on plain nodes clip away from node centers" {
  let graph = try @dot_parser.parse_dot(
    "digraph { foo:s -> bar:n [dir=both arrowhead=crow arrowtail=crow] }",
  ) catch {
    err => fail("parse failed: \{err}")
  } noraise {
    value => value
  }
  let layout = layout_dot(graph)
  layout.apply()
  let edges = graph.edges()
  assert_eq(edges.length(), 1)
  let pos = match edges[0].get_attr("pos") {
    Some(value) => value
    None => fail("missing edge pos")
  }
  let numbers = try extract_numbers(pos) catch {
    err => fail("extract_numbers failed: \{err}")
  } noraise {
    value => value
  }
  if numbers.length() < 4 {
    fail("unexpected pos attr: \{pos}")
  }
  let tail_y = numbers[1]
  let head_y = numbers[3]
  // Centers for default nodes are near y=90 and y=18; port clipping should
  // move anchors toward boundaries around y=72 and y=36.
  assert_true(tail_y < 80.0)
  assert_true(head_y > 30.0)
}

///|
test "dot layout tier2 snapshots" {
  if !full_parity_tests_enabled() {
    return
  }
  let cases = dot_snapshot_cases("tests/layout/dot/cases.txt", "tests/layout/dot")
  if cases.length() == 0 {
    fail("no dot fixtures under tests/layout/dot")
  }
  for pair in cases {
    let (input_path, expected_path) = pair
    assert_snapshot(input_path, expected_path, 0.01)
  }
}
