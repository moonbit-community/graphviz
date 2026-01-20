///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
priv struct ArrowFlags {
  head : Bool
  tail : Bool
}

const LINE_SPACING : Double = 1.2

const TEXT_SCALE : Double = 0.9706

///|
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
}

priv struct LabelLine {
  text : String
  align : @render.TextAlign
  width_pt : Double
}

///|
fn char_width_units(ch : Char) -> Int {
  match ch {
    ' ' => 250
    '\t' => 250
    '!' => 333
    '"' => 408
    '#' => 500
    '$' => 500
    '%' => 833
    '&' => 778
    '\'' => 180
    '(' | ')' | '[' | ']' => 333
    '*' => 500
    '+' | '<' | '=' | '>' => 564
    ',' | '.' => 250
    '-' => 333
    '/' | '\\' => 278
    '0'..='9' => 500
    ':' | ';' => 278
    '?' => 444
    '@' => 921
    'A' => 722
    'B' => 667
    'C' => 667
    'D' => 722
    'E' => 611
    'F' => 556
    'G' => 722
    'H' => 722
    'I' => 333
    'J' => 389
    'K' => 722
    'L' => 611
    'M' => 889
    'N' => 722
    'O' => 722
    'P' => 556
    'Q' => 722
    'R' => 667
    'S' => 556
    'T' => 611
    'U' => 722
    'V' => 722
    'W' => 944
    'X' => 722
    'Y' => 722
    'Z' => 611
    '^' => 469
    '_' => 500
    '`' => 333
    'a' => 444
    'b' => 500
    'c' => 444
    'd' => 500
    'e' => 444
    'f' => 333
    'g' => 500
    'h' => 500
    'i' => 278
    'j' => 278
    'k' => 500
    'l' => 278
    'm' => 820
    'n' => 500
    'o' => 500
    'p' => 500
    'q' => 500
    'r' => 333
    's' => 389
    't' => 278
    'u' => 500
    'v' => 500
    'w' => 722
    'x' => 500
    'y' => 500
    'z' => 444
    '{' => 480
    '|' => 200
    '}' => 480
    '~' => 541
    _ => 500
  }
}

///|
fn push_label_line(
  lines : Array[LabelLine],
  text : String,
  align : @render.TextAlign,
  width_units : Int,
  font_size_pt : Double,
) -> Unit {
  let width_pt = width_units.to_double() * font_size_pt * TEXT_SCALE / 1000.0
  lines.push({ text, align, width_pt })
}

// Heuristic line heights tuned to Graphviz xdot baselines for common fonts.
fn line_height_scale(font_name : String, font_size_pt : Double) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.125
  } else if lower.contains("times") {
    let min_size = 10.0
    let max_size = 14.0
    if font_size_pt <= min_size {
      1.125
    } else if font_size_pt >= max_size {
      1.1786
    } else {
      let t = (font_size_pt - min_size) / (max_size - min_size)
      1.125 + t * (1.1786 - 1.125)
    }
  } else {
    LINE_SPACING
  }
}

///|
fn line_height(font_name : String, font_size_pt : Double) -> Double {
  font_size_pt * line_height_scale(font_name, font_size_pt)
}

///|
fn centerline_offset(font_size_pt : Double) -> Double {
  font_size_pt * 0.05
}

///|
fn label_lines(label : String, font_size_pt : Double) -> Array[LabelLine] {
  let lines : Array[LabelLine] = []
  let mut sb = StringBuilder::new()
  let mut current_units = 0
  let mut has_chars = false
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      match ch {
        'n' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Center,
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        'l' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Left,
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        'r' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Right,
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          current_units = current_units + char_width_units(ch)
          has_chars = true
        }
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      push_label_line(
        lines,
        sb.to_string(),
        @render.TextAlign::Center,
        current_units,
        font_size_pt,
      )
      sb = StringBuilder::new()
      current_units = 0
      has_chars = false
      continue
    }
    sb.write_char(ch)
    current_units = current_units + char_width_units(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    current_units = current_units + char_width_units('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
      current_units,
      font_size_pt,
    )
  }
  lines
}

///|
fn label_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let raw_lines = label_lines(label, font_size_pt)
  let width_scale = font_width_scale(font_name)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  for line in raw_lines {
    let width_pt = line.width_pt * width_scale
    if width_pt > max_width {
      max_width = width_pt
    }
    lines.push({ text: line.text, align: line.align, width_pt })
  }
  let height_pt = line_height(font_name, font_size_pt) * lines.length().to_double()
  (lines, max_width, height_pt)
}

///|
fn resolve_label(text : String, name : String) -> String {
  let with_name = text.replace_all(old="\\N", new=name)
  with_name.replace_all(old="\\n", new="\n")
}

///|
fn label_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) => resolve_label(text, fallback)
    None => fallback
  }
}

///|
fn shape_kind(value : String?) -> String {
  let shape = match value {
    Some(text) => text.to_lower()
    None => "ellipse"
  }
  match shape {
    "box" | "rect" | "rectangle" => "box"
    "point" | "dot" => "point"
    "ellipse" | "oval" | "circle" => "ellipse"
    _ => "ellipse"
  }
}

///|
fn has_filled_style(value : String?) -> Bool {
  match value {
    Some(text) => text.to_lower().contains("filled")
    None => false
  }
}

///|
fn font_size(value : String?) -> Double {
  match value {
    Some(text) => parse_double(text, 14.0)
    None => 14.0
  }
}

///|
fn font_name(value : String?) -> String {
  match value {
    Some(text) => text
    None => "Times-Roman"
  }
}

///|
fn arrow_flags(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> ArrowFlags {
  if kind != @cgraph.GraphKind::Directed {
    return { head: false, tail: false }
  }
  let dir = match edge.get_attr("dir") {
    Some(value) => value.to_lower()
    None => "forward"
  }
  let mut head = true
  let mut tail = false
  match dir {
    "none" => {
      head = false
      tail = false
    }
    "back" => {
      head = false
      tail = true
    }
    "both" => {
      head = true
      tail = true
    }
    _ => ()
  }
  let head_shape = match edge.get_attr("arrowhead") {
    Some(value) => value.to_lower()
    None => ""
  }
  if head_shape == "none" {
    head = false
  }
  let tail_shape = match edge.get_attr("arrowtail") {
    Some(value) => value.to_lower()
    None => ""
  }
  if tail_shape == "none" {
    tail = false
  }
  { head, tail }
}

///|
fn arrow_size(edge : @cgraph.Edge) -> Double {
  match edge.get_attr("arrowsize") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
}

///|
fn arrow_primitives(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@render.DrawOp] {
  if layout.splines.length() == 0 {
    return []
  }
  let spline = if at_head {
    layout.splines[layout.splines.length() - 1]
  } else {
    layout.splines[0]
  }
  if spline.points.length() < 2 {
    return []
  }
  let tip = if at_head {
    spline.points[spline.points.length() - 1]
  } else {
    spline.points[0]
  }
  let from = if at_head {
    spline.points[spline.points.length() - 2]
  } else {
    spline.points[1]
  }
  let arrowhead = if at_head {
    layout.edge.get_attr("arrowhead")
  } else {
    layout.edge.get_attr("arrowtail")
  }
  @render.arrow_primitives(tip, from, arrow_size(layout.edge), arrowhead)
}

///|
fn escape_xml(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&apos;")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}

///|
fn node_rect(layout : @layout_dot.DotLayoutNode) -> @geom.Rect {
  let half_w = layout.width_in * 72.0 / 2.0
  let half_h = layout.height_in * 72.0 / 2.0
  {
    llx: layout.pos.x - half_w,
    lly: layout.pos.y - half_h,
    urx: layout.pos.x + half_w,
    ury: layout.pos.y + half_h,
  }
}

///|
fn shift_point(point : @geom.Point, llx : Double, lly : Double) -> @geom.Point {
  { x: point.x - llx, y: point.y - lly }
}

///|
fn spline_path(
  spline : @geom.Spline,
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  let points = spline.points
  if points.length() == 0 {
    return ""
  }
  let first = shift_point(points[0], llx, lly)
  sb.write_string("M ")
  sb.write_string(first.x.to_string())
  sb.write_char(' ')
  sb.write_string(first.y.to_string())
  let mut index = 1
  while index + 2 < points.length() {
    let p1 = shift_point(points[index], llx, lly)
    let p2 = shift_point(points[index + 1], llx, lly)
    let p3 = shift_point(points[index + 2], llx, lly)
    sb.write_string(" C ")
    sb.write_string(p1.x.to_string())
    sb.write_char(' ')
    sb.write_string(p1.y.to_string())
    sb.write_char(' ')
    sb.write_string(p2.x.to_string())
    sb.write_char(' ')
    sb.write_string(p2.y.to_string())
    sb.write_char(' ')
    sb.write_string(p3.x.to_string())
    sb.write_char(' ')
    sb.write_string(p3.y.to_string())
    index = index + 3
  }
  sb.to_string()
}

///|
fn polygon_points(
  points : Array[@geom.Point],
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  for i in 0..<points.length() {
    let point = shift_point(points[i], llx, lly)
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(point.x.to_string())
    sb.write_char(',')
    sb.write_string(point.y.to_string())
  }
  sb.to_string()
}

///|
fn write_arrow_ops(
  sb : StringBuilder,
  ops : Array[@render.DrawOp],
  color : String,
  llx : Double,
  lly : Double,
  indent : String,
  pretty : Bool,
) -> Unit {
  for op in ops {
    match op {
      @render.DrawOp::Polygon(filled~, points~) => {
        let attrs = polygon_points(points, llx, lly)
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<polygon points=\"\{attrs}\" fill=\"\{fill}\" stroke=\"\{color}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Ellipse(filled~, rect~) => {
        let center_x = (rect.llx + rect.urx) / 2.0 - llx
        let center_y = (rect.lly + rect.ury) / 2.0 - lly
        let radius_x = (rect.urx - rect.llx) / 2.0
        let radius_y = (rect.ury - rect.lly) / 2.0
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<ellipse cx=\"\{center_x}\" cy=\"\{center_y}\" rx=\"\{radius_x}\" ry=\"\{radius_y}\" fill=\"\{fill}\" stroke=\"\{color}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Polyline(points~) => {
        let attrs = polygon_points(points, llx, lly)
        write_line(
          sb,
          "<polyline points=\"\{attrs}\" fill=\"none\" stroke=\"\{color}\"/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Bezier(filled~, points~) => {
        let _ = filled
        let path = spline_path(@geom.Spline::{ start: None, end: None, points }, llx, lly)
        if path != "" {
          write_line(
            sb,
            "<path d=\"\{path}\" fill=\"none\" stroke=\"\{color}\"/>",
            indent,
            pretty,
          )
        }
      }
      _ => ()
    }
  }
}

///|
fn write_line(
  sb : StringBuilder,
  text : String,
  indent : String,
  pretty : Bool,
) -> Unit {
  if pretty {
    sb.write_string(indent)
  }
  sb.write_string(text)
  if pretty {
    sb.write_char('\n')
  }
}

///|
pub fn SvgOptions::default() -> SvgOptions {
  { pretty: Some(true), include_xml_decl: Some(true) }
}

///|
pub fn render_svg(
  layout : @layout_dot.DotLayoutGraph,
  options? : SvgOptions = SvgOptions::default(),
) -> String {
  let opts = options
  let pretty = match opts.pretty {
    Some(value) => value
    None => true
  }
  let include_xml_decl = match opts.include_xml_decl {
    Some(value) => value
    None => true
  }
  let bbox = layout.bbox
  let width = bbox.urx - bbox.llx
  let height = bbox.ury - bbox.lly
  let sb = StringBuilder::new()
  if include_xml_decl {
    write_line(sb, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "", pretty)
  }
  write_line(
    sb,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}pt\" height=\"\{height}pt\" viewBox=\"0 0 \{width} \{height}\">",
    "",
    pretty,
  )
  write_line(
    sb,
    "<g transform=\"translate(0 \{height}) scale(1 -1)\">",
    "  ",
    pretty,
  )
  let edge_indent = if pretty { "    " } else { "" }
  let kind = layout.graph.kind()
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    let color = match edge.get_attr("color") {
      Some(value) => value
      None => "black"
    }
    for spline in edge_layout.splines {
      let path = spline_path(spline, bbox.llx, bbox.lly)
      if path != "" {
        write_line(
          sb,
          "<path d=\"\{path}\" fill=\"none\" stroke=\"\{color}\"/>",
          edge_indent,
          pretty,
        )
      }
    }
    let flags = arrow_flags(edge, kind)
    if flags.head {
      let ops = arrow_primitives(edge_layout, true)
      write_arrow_ops(sb, ops, color, bbox.llx, bbox.lly, edge_indent, pretty)
    }
    if flags.tail {
      let ops = arrow_primitives(edge_layout, false)
      write_arrow_ops(sb, ops, color, bbox.llx, bbox.lly, edge_indent, pretty)
    }
  }
  let node_indent = if pretty { "    " } else { "" }
  for node_layout in layout.nodes {
    let node = node_layout.node
    let rect = node_rect(node_layout)
    let kind = shape_kind(node.get_attr("shape"))
    let stroke = match node.get_attr("color") {
      Some(value) => value
      None => "black"
    }
    let filled = if kind == "point" {
      true
    } else {
      has_filled_style(node.get_attr("style"))
    }
    let fill = if filled {
      match node.get_attr("fillcolor") {
        Some(value) => value
        None => {
          if kind == "point" {
            stroke
          } else {
            "white"
          }
        }
      }
    } else {
      "none"
    }
    if kind == "box" {
      let x = rect.llx - bbox.llx
      let y = rect.lly - bbox.lly
      let w = rect.urx - rect.llx
      let h = rect.ury - rect.lly
      write_line(
        sb,
        "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\" stroke=\"\{stroke}\"/>",
        node_indent,
        pretty,
      )
    } else {
      let cx = node_layout.pos.x - bbox.llx
      let cy = node_layout.pos.y - bbox.lly
      let rx = (rect.urx - rect.llx) / 2.0
      let ry = (rect.ury - rect.lly) / 2.0
      write_line(
        sb,
        "<ellipse cx=\"\{cx}\" cy=\"\{cy}\" rx=\"\{rx}\" ry=\"\{ry}\" fill=\"\{fill}\" stroke=\"\{stroke}\"/>",
        node_indent,
        pretty,
      )
    }
    let text = label_text(node.get_attr("label"), node.name())
    if text != "" {
      let font = font_name(node.get_attr("fontname"))
      let size = font_size(node.get_attr("fontsize"))
      let color = match node.get_attr("fontcolor") {
        Some(value) => value
        None => "black"
      }
      let pos = match node_layout.label_pos {
        Some(value) => value
        None => node_layout.pos
      }
      let (lines, max_width, total_height) = label_metrics(text, font, size)
      let line_step = line_height(font, size)
      let start_y = pos.y + total_height / 2.0 - size + centerline_offset(size)
      for i in 0..<lines.length() {
        let line = lines[i]
        if line.text == "" {
          continue
        }
        let line_x = match line.align {
          @render.TextAlign::Left => pos.x - max_width / 2.0
          @render.TextAlign::Right => pos.x + max_width / 2.0
          @render.TextAlign::Center => pos.x
        }
        let line_y = start_y - line_step * i.to_double()
        let anchor = match line.align {
          @render.TextAlign::Left => "start"
          @render.TextAlign::Right => "end"
          @render.TextAlign::Center => "middle"
        }
        let x = line_x - bbox.llx
        let y = bbox.lly - line_y
        let escaped = escape_xml(line.text)
        write_line(
          sb,
          "<text x=\"\{x}\" y=\"\{y}\" transform=\"scale(1 -1)\" text-anchor=\"\{anchor}\" font-family=\"\{font}\" font-size=\"\{size}\" fill=\"\{color}\">\{escaped}</text>",
          node_indent,
          pretty,
        )
      }
    }
  }
  write_line(sb, "</g>", "  ", pretty)
  write_line(sb, "</svg>", "", pretty)
  sb.to_string()
}
