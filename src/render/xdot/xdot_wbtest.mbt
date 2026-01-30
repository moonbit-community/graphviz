///|
fn parse_point(text : String) -> @geom.Point? {
  let parts : Array[String] = []
  for part_view in text.split(",") {
    parts.push(part_view.trim(chars=" \n\r\t").to_string())
  }
  if parts.length() < 2 {
    return None
  }
  let x = parse_double(parts[0], 0.0)
  let y = parse_double(parts[1], 0.0)
  Some({ x, y })
}

///|
fn edge_label_positions(
  graph : @cgraph.Graph,
  label : String,
) -> Array[@geom.Point] {
  let positions : Array[@geom.Point] = []
  for edge in graph.edges() {
    match edge.get_attr("label") {
      Some(value) =>
        if value == label {
          match edge.get_attr("lp") {
            Some(lp) =>
              match parse_point(lp) {
                Some(pos) => positions.push(pos)
                None => ()
              }
            None => ()
          }
        }
      None => ()
    }
  }
  positions
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps : Double,
) -> Unit raise {
  let dx = Double::abs(actual.x - expected.x)
  let dy = Double::abs(actual.y - expected.y)
  guard dx <= eps && dy <= eps else {
    fail(
      "pos drift: got (\{actual.x},\{actual.y}) expected (\{expected.x},\{expected.y})",
    )
  }
}

///|
fn assert_edge_label_parity(
  actual : @cgraph.Graph,
  expected : @cgraph.Graph,
  label : String,
  eps : Double,
) -> Unit raise {
  let actual_positions = edge_label_positions(actual, label)
  let expected_positions = edge_label_positions(expected, label)
  assert_eq(actual_positions.length(), expected_positions.length())
  if actual_positions.length() > 1 {
    actual_positions.sort_by((a, b) => Double::compare(a.x, b.x))
    expected_positions.sort_by((a, b) => Double::compare(a.x, b.x))
  }
  for i in 0..<actual_positions.length() {
    assert_point_close(actual_positions[i], expected_positions[i], eps)
  }
}

///|
#skip
test "render_xdot matches graphviz edge label positions" {
  let cases : Array[(String, String, Array[String])] = [
    (
      "tests/layout/dot/edge_label_spacing.dot",
      "tests/layout/dot/edge_label_spacing.gv.dot",
      ["Edge Label A", "Edge Label B Longer"],
    ),
    (
      "tests/layout/dot/edge_vnode_spacing.dot",
      "tests/layout/dot/edge_vnode_spacing.gv.dot",
      ["Very Long Edge Label"],
    ),
  ]
  let eps = 1.5
  for entry in cases {
    let (input_path, reference_path, labels) = entry
    let graph = @dot.parse_dot_file(input_path)
    let layout = @layout_dot.layout_dot(graph)
    let output = render_xdot(layout)
    let output_graph = @dot.parse_dot(output)
    let reference = @dot.parse_dot_file(reference_path)
    for label in labels {
      assert_edge_label_parity(output_graph, reference, label, eps)
    }
  }
}
