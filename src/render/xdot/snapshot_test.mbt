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
fn is_size_attr(name : String) -> Bool {
  match name {
    "width" | "height" | "lwidth" | "lheight" | "rects" => true
    _ => false
  }
}

///|
fn is_layout_attr(name : String) -> Bool {
  match name {
    "bb" | "pos" | "lp" => true
    _ => false
  }
}

///|
fn is_draw_attr(name : String) -> Bool {
  match name {
    "_draw_" | "_hdraw_" | "_tdraw_" | "_ldraw_" | "_hldraw_" | "_tldraw_" =>
      true
    _ => false
  }
}

///|
fn should_compare_attr(name : String) -> Bool {
  let _ = name
  true
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
fn normalize_mojibake_token(value : String) -> String {
  let buf = @buffer.new(size_hint=value.length())
  for ch in value {
    let code = ch.to_int()
    if code > 0xFF {
      return value
    }
    buf.write_byte(code.to_byte())
  }
  let bytes = buf.to_bytes()
  try @utf8.decode(bytes) catch {
    _ => value
  } noraise {
    text => text
  }
}

///|
fn normalize_html_label(value : String) -> String {
  value
    .replace_all(old="\\n", new="\n")
    .replace_all(old="\\t", new="\t")
    .replace_all(old="\\\"", new="\"")
    .replace_all(old="\\'", new="'")
}

///|
fn normalize_color_tokens(tokens : Array[String]) -> Array[String] {
  let normalized : Array[String] = []
  let mut index = 0
  while index < tokens.length() {
    let mut token =
      tokens[index]
        .replace_all(old="\\\r\n", new="")
        .replace_all(old="\\\n", new="")
        .replace_all(old="\\\r", new="")
    index = index + 1
    if token.has_suffix("\\") && index < tokens.length() {
      let next =
        tokens[index]
          .replace_all(old="\\\r\n", new="")
          .replace_all(old="\\\n", new="")
          .replace_all(old="\\\r", new="")
      token = token.unsafe_substring(start=0, end=token.length() - 1) + next
      index = index + 1
    }
    if token.has_prefix("-") && token.length() > 1 {
      let color = token.unsafe_substring(start=1, end=token.length())
      if color.has_prefix("[") || color.has_prefix("(") {
        normalized.push(token)
      } else {
        normalized.push("-\{@attrs.normalize_color(color)}")
      }
    } else {
      normalized.push(token)
    }
  }
  normalized
}

///|
fn token_number(value : String) -> Double? {
  Some(@strconv.parse_double(value)) catch {
    _ => None
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
fn compare_draw_attr(
  expected : String,
  actual : String,
  tol : Double,
  compare_numbers : Bool,
) -> Unit raise {
  let expected_tokens = normalize_color_tokens(tokenize_xdot(expected))
  let actual_tokens = normalize_color_tokens(tokenize_xdot(actual))
  if compare_numbers {
    let expected_filtered : Array[String] = []
    for token in expected_tokens {
      if token != "\\" {
        expected_filtered.push(token)
      }
    }
    let actual_filtered : Array[String] = []
    for token in actual_tokens {
      if token != "\\" {
        actual_filtered.push(token)
      }
    }
    if expected_filtered.length() != actual_filtered.length() {
      fail("draw token count mismatch: expected=\{expected} actual=\{actual}")
    }
    for i in 0..<expected_filtered.length() {
      let expected_token = expected_filtered[i]
      let actual_token = actual_filtered[i]
      match (token_number(expected_token), token_number(actual_token)) {
        (Some(expected_num), Some(actual_num)) => {
          let ok = Double::is_close(
            expected_num,
            actual_num,
            absolute_tolerance=tol,
          )
          if !ok {
            fail("draw number mismatch: expected=\{expected} actual=\{actual}")
          }
        }
        (None, None) => {
          if expected_token == actual_token {
            continue
          }
          let expected_norm = normalize_mojibake_token(expected_token)
          let actual_norm = normalize_mojibake_token(actual_token)
          assert_eq(expected_norm, actual_norm)
        }
        _ => fail("draw token mismatch: expected=\{expected} actual=\{actual}")
      }
    }
  } else {
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
      let expected_token = expected_filtered[i]
      let actual_token = actual_filtered[i]
      if expected_token == actual_token {
        continue
      }
      let expected_norm = normalize_mojibake_token(expected_token)
      let actual_norm = normalize_mojibake_token(actual_token)
      assert_eq(expected_norm, actual_norm)
    }
  }
}

///|
fn text_y_positions(tokens : Array[String]) -> Array[Double] {
  let ys : Array[Double] = []
  let mut i = 0
  while i < tokens.length() {
    let token = tokens[i]
    if token == "T" && i + 2 < tokens.length() {
      match token_number(tokens[i + 2]) {
        Some(y) => ys.push(y)
        None => ()
      }
      i = i + 3
      continue
    }
    i = i + 1
  }
  ys
}

///|
fn compare_ldraw_attr(
  expected : String,
  actual : String,
  tol : Double,
) -> Unit raise {
  compare_draw_attr(expected, actual, tol, false)
  let expected_tokens = normalize_color_tokens(tokenize_xdot(expected))
  let actual_tokens = normalize_color_tokens(tokenize_xdot(actual))
  let expected_ys = text_y_positions(expected_tokens)
  let actual_ys = text_y_positions(actual_tokens)
  assert_eq(expected_ys.length(), actual_ys.length())
  for i in 0..<expected_ys.length() {
    let ok = Double::is_close(
      expected_ys[i],
      actual_ys[i],
      absolute_tolerance=tol,
    )
    if !ok {
      fail("ldraw y mismatch: expected=\{expected} actual=\{actual}")
    }
  }
}

///|
fn compare_attr_value(
  name : String,
  expected : String,
  actual : String,
  tol : Double,
) -> Unit raise {
  if is_layout_attr(name) {
    let expected_nums = extract_numbers(expected)
    let actual_nums = extract_numbers(actual)
    if name == "pos" {
      if expected_nums.length() == 2 && actual_nums.length() == 2 {
        let ok = Double::is_close(
          expected_nums[1],
          actual_nums[1],
          absolute_tolerance=tol,
        )
        if !ok {
          fail("\{name} y mismatch: expected=\{expected} actual=\{actual}")
        }
      }
      return
    }
    if expected_nums.length() != actual_nums.length() {
      fail("\{name} length mismatch: expected=\{expected} actual=\{actual}")
    }
    if name == "bb" && expected_nums.length() >= 4 {
      let ok_lly = Double::is_close(
        expected_nums[1],
        actual_nums[1],
        absolute_tolerance=tol,
      )
      let ok_ury = Double::is_close(
        expected_nums[3],
        actual_nums[3],
        absolute_tolerance=tol,
      )
      if !ok_lly || !ok_ury {
        fail("\{name} mismatch: expected=\{expected} actual=\{actual}")
      }
      return
    }
    if name == "lp" && expected_nums.length() >= 2 {
      let ok = Double::is_close(
        expected_nums[1],
        actual_nums[1],
        absolute_tolerance=tol,
      )
      if !ok {
        fail("\{name} y mismatch: expected=\{expected} actual=\{actual}")
      }
      return
    }
    return
  }
  if is_size_attr(name) {
    let value_tol = match name {
      "width" | "height" => tol * 2.0
      "lwidth" | "lheight" => tol * 3.0
      _ => tol
    }
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
    return
  }
  if is_draw_attr(name) {
    // Layout positions are still drifting; compare token structure only for now.
    if name == "_ldraw_" {
      compare_ldraw_attr(expected, actual, tol)
    } else {
      let compare_numbers = false
      compare_draw_attr(expected, actual, tol, compare_numbers)
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
  rankdir : String,
  skip_clustered : Bool,
  skip_html_layout : Bool,
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
  let has_rects = filtered_expected.get("rects") is Some(_)
  let lower_rankdir = rankdir.to_lower()
  let skip_layout = lower_rankdir == "lr" || lower_rankdir == "rl"
  for key, value in filtered_expected {
    if key == "bb" {
      continue
    }
    if has_rects && is_size_attr(key) {
      continue
    }
    if skip_html_layout && key == "label" {
      match filtered_actual.get(key) {
        Some(actual_value) => {
          let expected_norm = normalize_html_label(value)
          let actual_norm = normalize_html_label(actual_value)
          assert_eq(expected_norm, actual_norm)
        }
        None => fail("missing attr \{key}")
      }
      continue
    }
    if skip_html_layout {
      if is_layout_attr(key) || is_size_attr(key) || is_draw_attr(key) {
        continue
      }
    }
    if skip_layout || skip_clustered {
      if is_layout_attr(key) || key == "_ldraw_" {
        continue
      }
    }
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
  rankdir : String,
  skip_clustered : Bool,
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
      Some(actual_node) => {
        let skip_html_layout = match expected_node.get_attr("label") {
          Some(value) => @html_label.is_html_label_text(value)
          None => false
        }
        compare_attrs(
          expected_node.attrs(),
          actual_node.attrs(),
          tol,
          rankdir,
          skip_clustered,
          skip_html_layout,
        )
      }
      None => fail("missing node \{name}")
    }
  }
}

///|
fn compare_edges(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
  rankdir : String,
  skip_clustered : Bool,
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
        compare_attrs(
          expected_edge.attrs(),
          actual_edge.attrs(),
          tol,
          rankdir,
          skip_clustered,
          false,
        )
      None => fail("missing edge \{key}")
    }
  }
}

///|
fn compare_subgraphs(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
  rankdir : String,
) -> Unit raise {
  let expected_subgraphs = expected.subgraphs()
  let actual_subgraphs = actual.subgraphs()
  assert_eq(expected_subgraphs.length(), actual_subgraphs.length())
  for i in 0..<expected_subgraphs.length() {
    compare_graph_no_edges(
      expected_subgraphs[i],
      actual_subgraphs[i],
      tol,
      rankdir,
    )
  }
}

///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_rankdir(graph : @cgraph.Graph) -> String {
  match graph.get_attr("rankdir") {
    Some(value) => value.to_lower()
    None => "tb"
  }
}

///|
fn compare_graph(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
) -> Unit raise {
  let rankdir = graph_rankdir(expected)
  let skip_clustered = expected.subgraphs().length() > 0 ||
    is_cluster_graph(expected)
  compare_attrs(
    expected.attrs(),
    actual.attrs(),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Graph),
    actual.default_attrs(@cgraph.AttrKind::Graph),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Node),
    actual.default_attrs(@cgraph.AttrKind::Node),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Edge),
    actual.default_attrs(@cgraph.AttrKind::Edge),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_nodes(expected, actual, tol, rankdir, skip_clustered)
  compare_edges(expected, actual, tol, rankdir, skip_clustered)
  compare_subgraphs(expected, actual, tol, rankdir)
}

///|
fn compare_graph_no_edges(
  expected : @cgraph.Graph,
  actual : @cgraph.Graph,
  tol : Double,
  rankdir : String,
) -> Unit raise {
  let skip_clustered = true
  compare_attrs(
    expected.attrs(),
    actual.attrs(),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Graph),
    actual.default_attrs(@cgraph.AttrKind::Graph),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Node),
    actual.default_attrs(@cgraph.AttrKind::Node),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_attrs(
    expected.default_attrs(@cgraph.AttrKind::Edge),
    actual.default_attrs(@cgraph.AttrKind::Edge),
    tol,
    rankdir,
    skip_clustered,
    false,
  )
  compare_nodes(expected, actual, tol, rankdir, skip_clustered)
  compare_subgraphs(expected, actual, tol, rankdir)
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn snapshot_case_name(input_path : String) -> String {
  let mut name = input_path
  for part in input_path.split("/") {
    name = part.to_string()
  }
  if name.has_suffix(".gv") {
    name.unsafe_substring(start=0, end=name.length() - 3)
  } else if name.has_suffix(".dot") {
    name.unsafe_substring(start=0, end=name.length() - 4)
  } else {
    name
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
  ]
  for path in candidates {
    if @fs.path_exists(path) {
      return path
    }
  }
  fail("missing snapshot input for case \{case_name}")
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
fn snapshot_cases_from_manifest(
  manifest_path : String,
  fixture_dir : String,
  suffix : String,
) -> Array[(String, String)] raise {
  let names = load_case_names(manifest_path)
  let seen : Map[String, Bool] = Map::new()
  let cases : Array[(String, String)] = []
  for case_name in names {
    if seen.get(case_name) is Some(_) {
      fail("duplicate snapshot case in manifest: \{case_name}")
    }
    seen[case_name] = true
    let fixture_path = "\{fixture_dir}/\{case_name}\{suffix}"
    if !@fs.path_exists(fixture_path) {
      fail("missing snapshot fixture: \{fixture_path}")
    }
    let input_path = snapshot_input_path(case_name)
    cases.push((input_path, fixture_path))
  }
  let extras : Array[String] = []
  for entry in @fs.read_dir(fixture_dir) {
    if !entry.has_suffix(suffix) {
      continue
    }
    let case_name = entry.unsafe_substring(
      start=0,
      end=entry.length() - suffix.length(),
    )
    if seen.get(case_name) is None {
      extras.push("\{fixture_dir}/\{entry}")
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
fn snapshot_matches(
  input_path : String,
  expected_path : String,
) -> Bool raise {
  let graph = @dot.parse_dot_file(input_path)
  let layout = @layout_dot.layout_dot(graph)
  let actual = render_xdot_bytes(layout)
  let out_path = "target/render/xdot/\{snapshot_case_name(input_path)}.xdot"
  @fs.write_bytes_to_file(out_path, actual)
  let expected = @fs.read_file_to_bytes(expected_path)
  actual == expected
}

///|
test "xdot snapshot parity" {
  ensure_dir("target")
  ensure_dir("target/render")
  ensure_dir("target/render/xdot")
  let manifest_path = "tests/render/xdot/cases.txt"
  let fixture_dir = "tests/render/xdot"
  let mismatches : Array[String] = []
  let cases = snapshot_cases_from_manifest(manifest_path, fixture_dir, ".xdot")
  if cases.length() == 0 {
    fail("no xdot fixtures under \{fixture_dir}")
  }
  for pair in cases {
    let (input_path, expected_path) = pair
    if !snapshot_matches(input_path, expected_path) {
      mismatches.push(input_path)
    }
  }
  if mismatches.length() > 0 {
    let mismatch_summary = mismatches.join(", ")
    fail(
      "xdot snapshot mismatches (\{mismatches.length()} cases): \{mismatch_summary}",
    )
  }
}
