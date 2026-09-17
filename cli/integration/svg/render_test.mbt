// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @string.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn find_from(text : String, needle : String, start : Int) -> Int? {
  if start < 0 || start >= text.length() {
    return None
  }
  let rest = text.unsafe_substring(start~, end=text.length())
  match rest.find(needle) {
    Some(offset) => Some(start + offset)
    None => None
  }
}

///|
async test "render_svg keeps trapeziumlr node families as polygons" {
  let graph = @dot_fs.parse_dot_file(
    "../refs/graphviz/graphs/directed/trapeziumlr.gv",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg_renderer.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">Trapezium</text>"))
  assert_true(svg.contains("<polygon"))
  // trapeziumlr has only polygon-like node shapes; fallback ellipses indicate
  // shape mapping regression in SVG rendering.
  assert_true(!svg.contains("<ellipse"))
}

///|
async test "render_svg emits cluster labels" {
  let graph = @dot_fs.parse_dot_file(
    "../refs/graphviz/graphs/directed/clust.gv",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg_renderer.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">hello world</text>"))
  assert_true(svg.contains(">MSDOT</text>"))
}

///|
const DEFAULT_GRAPH_PAD_PT : Double = 4.0

///|
fn graph_pad_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph.get_attr("pad") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        parts.push(part.trim().to_owned())
      }
      let x_in = if parts.length() > 0 {
        parse_double(parts[0], DEFAULT_GRAPH_PAD_PT / 72.0)
      } else {
        DEFAULT_GRAPH_PAD_PT / 72.0
      }
      let y_in = if parts.length() > 1 {
        parse_double(parts[1], x_in)
      } else {
        x_in
      }
      (x_in * 72.0, y_in * 72.0)
    }
    None => (DEFAULT_GRAPH_PAD_PT, DEFAULT_GRAPH_PAD_PT)
  }
}

///|
fn svg_root_tag(svg : String) -> String? {
  match find_from(svg, "<svg", 0) {
    Some(start) =>
      match find_from(svg, ">", start) {
        Some(end_pos) => Some(svg.unsafe_substring(start~, end=end_pos + 1))
        None => None
      }
    None => None
  }
}

///|
fn parse_svg_size(svg : String) -> (Double, Double)? {
  match svg_root_tag(svg) {
    Some(tag) =>
      match
        (parse_attr_string(tag, "width"), parse_attr_string(tag, "height")) {
        (Some(width_text), Some(height_text)) => {
          let mut width = width_text.trim().to_owned()
          let mut height = height_text.trim().to_owned()
          if width.has_suffix("pt") {
            width = width.unsafe_substring(start=0, end=width.length() - 2)
          }
          if height.has_suffix("pt") {
            height = height.unsafe_substring(start=0, end=height.length() - 2)
          }
          Some((parse_double(width, 0.0), parse_double(height, 0.0)))
        }
        _ => None
      }
    None => None
  }
}

///|
fn assert_close(actual : Double, expected : Double, eps : Double) -> Unit raise {
  let delta = Double::abs(actual - expected)
  if delta > eps {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
fn size_scale_for_test(
  graph : @cgraph.Graph,
  width_pt : Double,
  height_pt : Double,
) -> (Double, Double, Double, Double) {
  let mut scale_x = 1.0
  let mut scale_y = 1.0
  let mut out_width = width_pt
  let mut out_height = height_pt
  match graph.get_attr("size") {
    Some(value) =>
      if width_pt > 0.0 && height_pt > 0.0 {
        let parts : Array[String] = []
        let mut force = false
        for part_view in value.split(",") {
          let part = part_view.trim().to_owned()
          if part.contains("!") {
            force = true
          }
          let cleaned = part.trim(chars=" \n\r\t!").to_owned()
          if cleaned != "" {
            parts.push(cleaned)
          }
        }
        if parts.length() > 0 {
          let width_in = parse_double(parts[0], -1.0)
          let height_in = if parts.length() > 1 {
            parse_double(parts[1], -1.0)
          } else {
            width_in
          }
          if width_in > 0.0 && height_in > 0.0 {
            let max_width = width_in * 72.0
            let max_height = height_in * 72.0
            let sx = max_width / width_pt
            let sy = max_height / height_pt
            if force {
              scale_x = sx
              scale_y = sy
              out_width = max_width
              out_height = max_height
            } else {
              let mut scale = if sx < sy { sx } else { sy }
              if scale > 1.0 {
                scale = 1.0
              }
              scale_x = scale
              scale_y = scale
              out_width = width_pt * scale
              out_height = height_pt * scale
            }
          }
        }
      }
    None => ()
  }
  (scale_x, scale_y, out_width, out_height)
}

///|
async test "render_svg honors size attribute" {
  let graph = @dot_fs.parse_dot_file("../refs/graphviz/graphs/directed/fig6.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg_renderer.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  let (width_pt, height_pt) = match parse_svg_size(svg) {
    Some(value) => value
    None => fail("missing svg size")
  }
  let (pad_x, pad_y) = graph_pad_pt(layout.graph)
  let width = layout.bbox.urx - layout.bbox.llx + pad_x * 2.0
  let height = layout.bbox.ury - layout.bbox.lly + pad_y * 2.0
  let (scale_x, scale_y, expected_width, expected_height) = size_scale_for_test(
    layout.graph,
    width,
    height,
  )
  assert_close(width_pt, expected_width, 0.5)
  assert_close(height_pt, expected_height, 0.5)
  if scale_x != 1.0 || scale_y != 1.0 {
    assert_true(svg.contains("scale("))
  }
}
