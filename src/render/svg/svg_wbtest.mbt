///|
priv struct SvgLabelEntry {
  center : @geom.Point
  width : Double
  height : Double
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
fn label_entry_rect(entry : SvgLabelEntry) -> @geom.Rect {
  rect_from_center(entry.center, entry.width, entry.height, 0.0)
}

///|
fn extract_label_entries(
  svg : String,
  label : String,
  bbox : @geom.Rect,
) -> Array[SvgLabelEntry] {
  let entries : Array[SvgLabelEntry] = []
  let mut skip_first = true
  for part_view in svg.split("<text ") {
    if skip_first {
      skip_first = false
      continue
    }
    let part = part_view.to_string()
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
            match (
              parse_attr_double(tag, "x"),
              parse_attr_double(tag, "y"),
              parse_attr_string(tag, "font-family"),
              parse_attr_double(tag, "font-size"),
            ) {
              (Some(x), Some(y), Some(font), Some(size)) => {
                let line_x = x + bbox.llx
                let line_y = bbox.lly - y
                let (_lines, width, height) = label_metrics(
                  label,
                  font,
                  size,
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
                let center_y = line_y - height / 2.0 + size -
                  centerline_offset(size)
                entries.push({
                  center: { x: center_x, y: center_y },
                  width,
                  height,
                })
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
fn svg_with_bbox(graph_path : String) -> (String, @geom.Rect) raise {
  let graph = @dot.parse_dot_file(graph_path)
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  let (pad_x, pad_y) = graph_pad_pt(layout.graph)
  let padded_bbox : @geom.Rect = {
    llx: layout.bbox.llx - pad_x,
    lly: layout.bbox.lly - pad_y,
    urx: layout.bbox.urx + pad_x,
    ury: layout.bbox.ury + pad_y,
  }
  (svg, padded_bbox)
}

///|
fn assert_edge_label_parity(
  svg : String,
  bbox : @geom.Rect,
  reference : @cgraph.Graph,
  label : String,
  eps : Double,
) -> Unit raise {
  let entries = extract_label_entries(svg, label, bbox)
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
  bbox : @geom.Rect,
  reference : @cgraph.Graph,
  label : String,
  eps : Double,
) -> Unit raise {
  let entries = extract_label_entries(svg, label, bbox)
  assert_eq(entries.length(), 1)
  let expected = match find_subgraph_label_pos(reference, label) {
    Some(pos) => pos
    None => fail("missing \{label} label position in reference")
  }
  assert_point_close(entries[0].center, expected, eps)
}

///|
test "render_svg matches graphviz label positions in complex" {
  let (svg, padded_bbox) = svg_with_bbox("tests/layout/dot/complex.dot")
  let reference = @dot.parse_dot_file("tests/layout/dot/complex.gv.dot")
  let eps = 2.0
  assert_edge_label_parity(svg, padded_bbox, reference, "MechCmd", eps)
  assert_edge_label_parity(svg, padded_bbox, reference, "Raw PROT_G", eps)
  assert_cluster_label_parity(svg, padded_bbox, reference, "ShipX", eps)
}

///|
test "render_svg matches graphviz edge label spacing" {
  let (svg, padded_bbox) =
    svg_with_bbox("tests/layout/dot/edge_label_spacing.dot")
  let reference =
    @dot.parse_dot_file("tests/layout/dot/edge_label_spacing.gv.dot")
  let eps = 1.5
  assert_edge_label_parity(svg, padded_bbox, reference, "Edge Label A", eps)
  assert_edge_label_parity(
    svg,
    padded_bbox,
    reference,
    "Edge Label B Longer",
    eps,
  )
}

///|
test "render_svg matches graphviz vnode edge label spacing" {
  let (svg, padded_bbox) =
    svg_with_bbox("tests/layout/dot/edge_vnode_spacing.dot")
  let reference =
    @dot.parse_dot_file("tests/layout/dot/edge_vnode_spacing.gv.dot")
  let eps = 1.5
  assert_edge_label_parity(
    svg,
    padded_bbox,
    reference,
    "Very Long Edge Label",
    eps,
  )
}
