// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
priv struct SvgLabelEntry {
  center : @geom.Point
}

///|
fn parse_attr_string(tag : String, name : String) -> String? {
  let needle = "\{name}=\""
  match tag.find(needle) {
    Some(start) => {
      let value_start = start + needle.length()
      let rest = tag.unsafe_substring(start=value_start, end=tag.length())
      match rest.find("\"") {
        Some(end_pos) => Some(rest.unsafe_substring(start=0, end=end_pos))
        None => None
      }
    }
    None => None
  }
}

///|
fn parse_attr_double(tag : String, name : String) -> Double? {
  match parse_attr_string(tag, name) {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
}

///|
fn extract_label_entries(svg : String, label : String) -> Array[SvgLabelEntry] {
  let entries : Array[SvgLabelEntry] = []
  let mut skip_first = true
  for part_view in svg.split("<text ") {
    if skip_first {
      skip_first = false
      continue
    }
    let part = part_view.to_owned()
    match part.find(">") {
      Some(end_pos) => {
        let tag = part.unsafe_substring(start=0, end=end_pos)
        let body = part.unsafe_substring(start=end_pos + 1, end=part.length())
        match body.find("</text>") {
          Some(close_pos) => {
            let text = body.unsafe_substring(start=0, end=close_pos)
            if text != label {
              continue
            }
            match
              (
                parse_attr_double(tag, "x"),
                parse_attr_double(tag, "y"),
                parse_attr_string(tag, "font-family"),
                parse_attr_double(tag, "font-size"),
              ) {
              (Some(x), Some(y), Some(font), Some(size)) => {
                let line_x = x
                let line_y = -y
                // These parity cases use simple, single-line labels.
                let (width, height, _layout_offset, yoffset) = @label_metrics.label_text_metrics(
                  label, font, size,
                )
                let anchor = match parse_attr_string(tag, "text-anchor") {
                  Some(value) => value
                  None => "middle"
                }
                let center_x = match anchor {
                  "start" => line_x + width / 2.0
                  "end" => line_x - width / 2.0
                  _ => line_x
                }
                let center_y = line_y - height / 2.0 + size - yoffset
                entries.push({ center: { x: center_x, y: center_y, }, })
              }
              _ => ()
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  entries
}

///|
fn parse_point(text : String) -> @geom.Point? {
  let parts : Array[String] = []
  for part_view in text.split(",") {
    parts.push(part_view.trim(chars=" \n\r\t!").to_owned())
  }
  if parts.length() < 2 {
    return None
  }
  let x = parse_double(parts[0], 0.0)
  let y = parse_double(parts[1], 0.0)
  Some({ x, y, })
}

///|
fn is_simple_label(text : String) -> Bool {
  if text == "" {
    return false
  }
  for ch in text {
    if ch == '\n' ||
      ch == '\r' ||
      ch == '{' ||
      ch == '}' ||
      ch == '|' ||
      ch == '<' ||
      ch == '>' ||
      ch == '\\' {
      return false
    }
  }
  true
}

///|
fn node_label_text(node : @cgraph.Node) -> String {
  node
  .get_attr("label")
  .unwrap_or(node.name())
  .replace_all(old="\\N", new=node.name())
}

///|
fn unique_simple_node_labels(graph : @cgraph.Graph) -> Array[String] {
  let counts : Map[String, Int] = Map([])
  for node in graph.nodes() {
    let label = node_label_text(node)
    if is_simple_label(label) {
      let count = match counts.get(label) {
        Some(value) => value
        None => 0
      }
      counts[label] = count + 1
    }
  }
  let labels : Array[String] = []
  for label, count in counts {
    if count == 1 {
      labels.push(label)
    }
  }
  labels.sort_by(String::compare)
  labels
}

///|
fn node_label_positions(
  graph : @cgraph.Graph,
  label : String,
) -> Array[@geom.Point] {
  let positions : Array[@geom.Point] = []
  for node in graph.nodes() {
    if node_label_text(node) == label {
      match node.get_attr("pos") {
        Some(pos) =>
          match parse_point(pos) {
            Some(point) => positions.push(point)
            None => ()
          }
        None => ()
      }
    }
  }
  positions
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
fn find_subgraph_label_pos(
  graph : @cgraph.Graph,
  label : String,
) -> @geom.Point? {
  for subgraph in graph.subgraphs() {
    match subgraph.get_attr("label") {
      Some(value) =>
        if value == label {
          match subgraph.get_attr("lp") {
            Some(lp) =>
              match parse_point(lp) {
                Some(pos) => return Some(pos)
                None => ()
              }
            None => ()
          }
        }
      None => ()
    }
    match find_subgraph_label_pos(subgraph, label) {
      Some(pos) => return Some(pos)
      None => ()
    }
  }
  None
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
async fn render_svg_file(graph_path : String) -> String {
  let graph = @dot_fs.parse_dot_file(graph_path)
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg_renderer.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  svg
}

///|
fn assert_edge_label_parity(
  svg : String,
  reference : @cgraph.Graph,
  label : String,
  eps : Double,
) -> Unit raise {
  let entries = extract_label_entries(svg, label)
  let expected = edge_label_positions(reference, label)
  assert_eq(entries.length(), expected.length())
  if entries.length() > 1 {
    entries.sort_by((a, b) => Double::compare(a.center.x, b.center.x))
    expected.sort_by((a, b) => Double::compare(a.x, b.x))
  }
  for i in 0..<entries.length() {
    assert_point_close(entries[i].center, expected[i], eps)
  }
}

///|
fn assert_cluster_label_parity(
  svg : String,
  reference : @cgraph.Graph,
  label : String,
  eps : Double,
) -> Unit raise {
  let entries = extract_label_entries(svg, label)
  assert_eq(entries.length(), 1)
  let expected = match find_subgraph_label_pos(reference, label) {
    Some(pos) => pos
    None => fail("missing \{label} label position in reference")
  }
  assert_point_close(entries[0].center, expected, eps)
}

///|
async test "render_svg matches graphviz label positions in complex" {
  let svg = render_svg_file("../tests/layout/dot/complex.dot")
  let reference = @dot_fs.parse_dot_file("../tests/layout/dot/complex.gv.dot")
  let eps = 2.0
  assert_edge_label_parity(svg, reference, "MechCmd", eps)
  assert_edge_label_parity(svg, reference, "Raw PROT_G", eps)
  assert_cluster_label_parity(svg, reference, "ShipX", eps)
}

///|
async test "render_svg matches graphviz node label positions in complex" {
  let svg = render_svg_file("../tests/layout/dot/complex.dot")
  let reference = @dot_fs.parse_dot_file("../tests/layout/dot/complex.gv.dot")
  let labels = unique_simple_node_labels(reference)
  let eps = 3.0
  for label in labels {
    let entries = extract_label_entries(svg, label)
    let expected = node_label_positions(reference, label)
    if entries.length() != 1 || expected.length() != 1 {
      fail("unexpected label count for \{label}")
    }
    assert_point_close(entries[0].center, expected[0], eps)
  }
}

///|
async test "render_svg matches graphviz edge label spacing" {
  let svg = render_svg_file("../tests/layout/dot/edge_label_spacing.dot")
  let reference = @dot_fs.parse_dot_file(
    "../tests/layout/dot/edge_label_spacing.gv.dot",
  )
  let eps = 1.5
  assert_edge_label_parity(svg, reference, "Edge Label A", eps)
  assert_edge_label_parity(svg, reference, "Edge Label B Longer", eps)
}

///|
async test "render_svg matches graphviz vnode edge label spacing" {
  let svg = render_svg_file("../tests/layout/dot/edge_vnode_spacing.dot")
  let reference = @dot_fs.parse_dot_file(
    "../tests/layout/dot/edge_vnode_spacing.gv.dot",
  )
  let eps = 1.5
  assert_edge_label_parity(svg, reference, "Very Long Edge Label", eps)
}
