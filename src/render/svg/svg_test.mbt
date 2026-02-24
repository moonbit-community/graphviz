///|
test "render_svg emits svg" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("<polygon"))
}

///|
test "render_svg emits root background" {
  let graph = @dot.parse_dot("digraph { bgcolor=\"pink\"; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon"))
  assert_true(svg.contains("fill=\"pink\""))
}

///|
test "render_svg emits edge labels" {
  let graph = @dot.parse_dot("digraph { a -> b [label=\"edge\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">edge</text>"))
}

///|
test "render_svg honors dashed and dotted styles" {
  let graph = @dot.parse_dot(
    "digraph { node [style=dotted]; a; b; a -> b [style=dashed]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("stroke-dasharray=\"1,5\""))
  assert_true(svg.contains("stroke-dasharray=\"5,2\""))
}

///|
test "render_svg expands rgba hex colors to opacity attrs" {
  let graph = @dot.parse_dot(
    "digraph { a [style=filled,color=\"#00ff005f\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"#00ff00\""))
  assert_true(svg.contains("fill-opacity=\"0.372549\""))
  assert_true(svg.contains("stroke=\"#00ff00\""))
  assert_true(svg.contains("stroke-opacity=\"0.372549\""))
  assert_true(!svg.contains("#00ff005f"))
}

///|
test "render_svg draws polygon node shapes" {
  let graph = @dot.parse_dot(
    "digraph { a [shape=diamond]; b [shape=triangle]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon"))
  assert_true(!svg.contains("<ellipse"))
}

///|
test "render_svg falls back unknown node shapes to box polygons" {
  let graph = @dot.parse_dot("digraph { a [style=filled shape=DFDbox]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon fill=\"lightgrey\" stroke=\"black\""))
}

///|
test "render_svg preserves forestgreen label color" {
  let graph = @dot.parse_dot("digraph { a [fontcolor=forestgreen]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"forestgreen\""))
}

///|
test "render_svg keeps trapeziumlr node families as polygons" {
  let graph = @dot.parse_dot_file("refs/graphviz/graphs/directed/trapeziumlr.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
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
test "render_svg skips outlines for plaintext nodes" {
  let graph = @dot.parse_dot("digraph { a [shape=plaintext,label=\"hello\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">hello</text>"))
  assert_true(!svg.contains("<ellipse"))
  assert_true(!svg.contains("<polygon fill=\"none\" stroke=\"black\""))
}

///|
test "render_svg renders record fields" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=record]; a [label=\"<f0>left|<f1>right\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains("<polyline"))
}

///|
test "render_svg renders nested record fields" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=record]; a [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">a</text>"))
  assert_true(svg.contains(">b</text>"))
  assert_true(svg.contains(">c</text>"))
  assert_true(svg.contains(">d</text>"))
  assert_true(svg.contains(">e</text>"))
  assert_true(svg.contains("<polyline"))
}

///|
test "render_svg renders html-like labels" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\"><TR><TD>left</TD><TD>right</TD></TR></TABLE>>]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains("<polygon") || svg.contains("<rect"))
}

///|
test "render_svg renders html label alignment and colors" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE BORDER=\\\"1\\\" CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\" BGCOLOR=\\\"yellow\\\"><TR><TD ALIGN=\\\"left\\\" BGCOLOR=\\\"red\\\">left</TD><TD ALIGN=\\\"right\\\">right</TD></TR><TR><TD COLSPAN=\\\"2\\\"><TABLE><TR><TD>inner</TD></TR></TABLE></TD></TR></TABLE>>]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">left</text>"))
  assert_true(svg.contains(">right</text>"))
  assert_true(svg.contains(">inner</text>"))
  assert_true(svg.contains("fill=\"yellow\""))
  assert_true(svg.contains("fill=\"red\""))
  assert_true(svg.contains("text-anchor=\"start\""))
  let left_x = match first_text_x(svg, "left") {
    Some(value) => value
    None => fail("missing left text x")
  }
  let right_x = match first_text_x(svg, "right") {
    Some(value) => value
    None => fail("missing right text x")
  }
  assert_true(left_x < right_x)
}

///|
test "render_svg emits cluster labels" {
  let graph = @dot.parse_dot_file("refs/graphviz/graphs/directed/clust.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">hello world</text>"))
  assert_true(svg.contains(">MSDOT</text>"))
}

///|
test "render_svg fills cluster background" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_0 { style=filled; color=lightgrey; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"lightgrey\""))
}

///|
test "render_svg skips empty cluster outlines" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_empty { label=\"empty\"; } subgraph cluster_full { label=\"full\"; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(!svg.contains("<title>cluster_empty</title>"))
  assert_true(svg.contains("<title>cluster_full</title>"))
}

///|
test "render_svg emits graph labels" {
  let graph = @dot.parse_dot(
    "digraph { label=\"Root\"; labelloc=t; labeljust=r; a -> b; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">Root</text>"))
}

///|
fn ensure_dir(path : String) -> Unit raise {
  if !@fs.path_exists(path) {
    @fs.create_dir(path)
  }
}

///|
fn normalize_text(text : String) -> String {
  let mut out = text.replace_all(old="&#45;", new="-")
  out = out.replace_all(old="&amp;", new="&")
  out = out.replace_all(old="&lt;", new="<")
  out = out.replace_all(old="&gt;", new=">")
  out = out.replace_all(old="&quot;", new="\"")
  out = out.replace_all(old="&apos;", new="'")
  out = out.replace_all(old="&#160;", new=" ")
  out = out.replace_all(old="&#xA0;", new=" ")
  out = out.replace_all(old="&#xa0;", new=" ")
  out.trim(chars=" \n\r\t").to_string()
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
const DEFAULT_GRAPH_PAD_PT : Double = 4.0

///|
fn graph_pad_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph.get_attr("pad") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        parts.push(part.trim().to_string())
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
fn find_from(text : String, needle : String, start : Int) -> Int? {
  if start < 0 || start >= text.length() {
    return None
  }
  let rest = text.unsafe_substring(start=start, end=text.length())
  match rest.find(needle) {
    Some(offset) => Some(start + offset)
    None => None
  }
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
fn first_text_x(svg : String, expected_text : String) -> Double? {
  let mut cursor = 0
  while true {
    let start = match find_from(svg, "<text", cursor) {
      Some(value) => value
      None => return None
    }
    let tag_end = match find_from(svg, ">", start) {
      Some(value) => value
      None => return None
    }
    let tag = svg.unsafe_substring(start=start, end=tag_end + 1)
    let x = parse_attr_double(tag, "x")
    let text_rest = svg.unsafe_substring(start=tag_end + 1, end=svg.length())
    let close_pos = match text_rest.find("</text>") {
      Some(value) => value
      None => return None
    }
    let text = normalize_text(
      text_rest.unsafe_substring(start=0, end=close_pos),
    )
    if text == expected_text {
      return x
    }
    cursor = tag_end + close_pos + "</text>".length()
  }
  None
}

///|
fn svg_root_tag(svg : String) -> String? {
  match find_from(svg, "<svg", 0) {
    Some(start) =>
      match find_from(svg, ">", start) {
        Some(end_pos) => Some(svg.unsafe_substring(start=start, end=end_pos + 1))
        None => None
      }
    None => None
  }
}

///|
fn parse_svg_size(svg : String) -> (Double, Double)? {
  match svg_root_tag(svg) {
    Some(tag) =>
      match (parse_attr_string(tag, "width"), parse_attr_string(tag, "height")) {
        (Some(width_text), Some(height_text)) => {
          let mut width = width_text.trim().to_string()
          let mut height = height_text.trim().to_string()
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
          let part = part_view.trim().to_string()
          if part.contains("!") {
            force = true
          }
          let cleaned = part.trim(chars=" \n\r\t!").to_string()
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
fn polygon_bbox(points : String) -> @geom.Rect? {
  let mut has_point = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for part_view in points.split(" ") {
    let token = part_view.trim(chars=" \n\r\t").to_string()
    if token == "" {
      continue
    }
    match token.find(",") {
      Some(comma) => {
        let x_text = token.unsafe_substring(start=0, end=comma)
        let y_text = token.unsafe_substring(start=comma + 1, end=token.length())
        let x = parse_double(x_text, 0.0)
        let y = -parse_double(y_text, 0.0)
        if !has_point {
          min_x = x
          max_x = x
          min_y = y
          max_y = y
          has_point = true
        } else {
          if x < min_x {
            min_x = x
          }
          if x > max_x {
            max_x = x
          }
          if y < min_y {
            min_y = y
          }
          if y > max_y {
            max_y = y
          }
        }
      }
      None => ()
    }
  }
  if has_point {
    Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  } else {
    None
  }
}

///|
fn extract_cluster_boxes_graphviz(svg : String) -> Map[String, @geom.Rect] {
  let boxes : Map[String, @geom.Rect] = Map::new()
  let mut cursor = 0
  let close_tag = "</g>"
  while true {
    match find_from(svg, "<g", cursor) {
      Some(start) => {
        let tag_end = match find_from(svg, ">", start) {
          Some(value) => value
          None => break
        }
        let tag = svg.unsafe_substring(start=start, end=tag_end + 1)
        if !tag.contains("class=\"cluster\"") {
          cursor = tag_end + 1
          continue
        }
        let block_end = match find_from(svg, close_tag, tag_end + 1) {
          Some(value) => value
          None => break
        }
        let block = svg.unsafe_substring(start=tag_end + 1, end=block_end)
        let polygon_start = match block.find("<polygon") {
          Some(value) => value
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let polygon_rest = block.unsafe_substring(start=polygon_start, end=block.length())
        let polygon_end = match polygon_rest.find(">") {
          Some(value) => value
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let polygon_tag = polygon_rest.unsafe_substring(start=0, end=polygon_end + 1)
        let rect = match parse_attr_string(polygon_tag, "points") {
          Some(points) =>
            match polygon_bbox(points) {
              Some(value) => value
              None => {
                cursor = block_end + close_tag.length()
                continue
              }
            }
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let text_start = match block.find("<text") {
          Some(value) => value
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let text_rest = block.unsafe_substring(start=text_start, end=block.length())
        let text_tag_end = match text_rest.find(">") {
          Some(value) => value
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let body = text_rest.unsafe_substring(
          start=text_tag_end + 1,
          end=text_rest.length(),
        )
        let close_pos = match body.find("</text>") {
          Some(value) => value
          None => {
            cursor = block_end + close_tag.length()
            continue
          }
        }
        let label = normalize_text(
          body.unsafe_substring(start=0, end=close_pos)
            .trim(chars=" \n\r\t")
            .to_string(),
        )
        if label != "" {
          boxes[label] = rect
        }
        cursor = block_end + close_tag.length()
      }
      None => break
    }
  }
  boxes
}

///|
fn extract_cluster_boxes(
  svg : String,
  padded_bbox : @geom.Rect,
) -> Map[String, @geom.Rect] {
  let boxes : Map[String, @geom.Rect] = Map::new()
  let section = match svg.find("<path") {
    Some(pos) => svg.unsafe_substring(start=0, end=pos)
    None => svg
  }
  let mut cursor = 0
  let mut pending_rect : @geom.Rect? = None
  let mut pending_used = false
  while true {
    let next_rect = find_from(section, "<rect", cursor)
    let next_text = find_from(section, "<text", cursor)
    let next = match (next_rect, next_text) {
      (None, None) => break
      (Some(a), None) => ("rect", a)
      (None, Some(b)) => ("text", b)
      (Some(a), Some(b)) => if a <= b { ("rect", a) } else { ("text", b) }
    }
    match next {
      ("rect", start) => {
        let tag_end = match find_from(section, ">", start) {
          Some(value) => value
          None => break
        }
        let tag = section.unsafe_substring(start=start, end=tag_end + 1)
        match (
          parse_attr_double(tag, "x"),
          parse_attr_double(tag, "y"),
          parse_attr_double(tag, "width"),
          parse_attr_double(tag, "height"),
        ) {
          (Some(x), Some(y), Some(width), Some(height)) => {
            let llx = x + padded_bbox.llx
            let ury = padded_bbox.lly - y
            let lly = ury - height
            pending_rect = Some({
              llx,
              lly,
              urx: llx + width,
              ury,
            })
            pending_used = false
          }
          _ => {
            pending_rect = None
            pending_used = false
          }
        }
        cursor = tag_end + 1
      }
      ("text", start) => {
        let tag_end = match find_from(section, ">", start) {
          Some(value) => value
          None => break
        }
        let text_rest = section.unsafe_substring(start=tag_end + 1, end=section.length())
        let close_pos = match text_rest.find("</text>") {
          Some(value) => value
          None => break
        }
        if !pending_used {
          match pending_rect {
            Some(rect) => {
              let label = normalize_text(
                text_rest.unsafe_substring(start=0, end=close_pos)
                  .trim(chars=" \n\r\t")
                  .to_string(),
              )
              if label != "" {
                boxes[label] = rect
                pending_used = true
              }
            }
            None => ()
          }
        }
        cursor = tag_end + close_pos + "</text>".length()
      }
      _ => ()
    }
  }
  boxes
}

///|
fn assert_rect_close(
  label : String,
  actual : @geom.Rect,
  expected : @geom.Rect,
  eps : Double,
) -> Unit raise {
  let dx1 = Double::abs(actual.llx - expected.llx)
  let dy1 = Double::abs(actual.lly - expected.lly)
  let dx2 = Double::abs(actual.urx - expected.urx)
  let dy2 = Double::abs(actual.ury - expected.ury)
  guard dx1 <= eps && dy1 <= eps && dx2 <= eps && dy2 <= eps else {
    fail(
      "cluster bbox drift for \{label}: got (\{actual.llx},\{actual.lly},\{actual.urx},\{actual.ury}) expected (\{expected.llx},\{expected.lly},\{expected.urx},\{expected.ury})",
    )
  }
}

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
fn validate_snapshot_manifest(
  manifest_path : String,
  fixture_dir : String,
  suffix : String,
) -> Array[String] raise {
  let case_names = load_case_names(manifest_path)
  let seen : Map[String, Bool] = Map::new()
  for case_name in case_names {
    if seen.get(case_name) is Some(_) {
      fail("duplicate snapshot case in manifest: \{case_name}")
    }
    seen[case_name] = true
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
  for case_name in case_names {
    let fixture_path = "\{fixture_dir}/\{case_name}\{suffix}"
    if !@fs.path_exists(fixture_path) {
      fail("missing snapshot fixture: \{fixture_path}")
    }
    ignore(snapshot_input_path(case_name))
  }
  case_names
}

///|
test "svg baseline fixture manifest coverage" {
  let case_names = validate_snapshot_manifest(
    "tests/render/svg/cases.txt",
    "tests/render/svg",
    ".svg",
  )
  ignore(case_names)
}

///|
test "render_svg honors size attribute" {
  let graph = @dot.parse_dot_file("refs/graphviz/graphs/directed/fig6.gv")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout, options={
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
  let (scale_x, scale_y, expected_width, expected_height) =
    size_scale_for_test(layout.graph, width, height)
  assert_close(width_pt, expected_width, 0.5)
  assert_close(height_pt, expected_height, 0.5)
  if scale_x != 1.0 || scale_y != 1.0 {
    assert_true(svg.contains("scale("))
  }
}

///|
test "svg snapshot parity" {
  let out_dir = "target/render/svg"
  let manifest_path = "tests/render/svg_snapshot/cases.txt"
  let fixture_dir = "tests/render/svg_snapshot"
  ensure_dir("target")
  ensure_dir("target/render")
  ensure_dir(out_dir)
  let mismatches : Array[String] = []
  let case_names = validate_snapshot_manifest(manifest_path, fixture_dir, ".svg")
  for case_name in case_names {
    let input_path = snapshot_input_path(case_name)
    let fixture_path = "\{fixture_dir}/\{case_name}.svg"
    let graph = @dot.parse_dot_file(input_path)
    let layout = @layout_dot.layout_dot(graph)
    let svg = render_svg(layout)
    let svg_bytes = @utf8.encode(svg, bom=false)
    let out_path = "\{out_dir}/\{case_name}.svg"
    @fs.write_bytes_to_file(out_path, svg_bytes)
    let fixture = @fs.read_file_to_bytes(fixture_path)
    if svg_bytes != fixture {
      mismatches.push(input_path)
    }
  }
  if mismatches.length() > 0 {
    let mismatch_summary = mismatches.join(", ")
    fail(
      "svg snapshot mismatches (\{mismatches.length()} cases): \{mismatch_summary}",
    )
  }
}

///|
test "render_svg cluster boxes match graphviz" {
  let graph = @dot.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(layout)
  let expected_svg = @fs.read_file_to_string("tests/render/svg/complex.svg")
  let expected = extract_cluster_boxes_graphviz(expected_svg)
  let actual = extract_cluster_boxes_graphviz(svg)
  let eps = 3.0
  for label, rect in expected {
    match actual.get(label) {
      Some(actual_rect) => assert_rect_close(label, actual_rect, rect, eps)
      None => fail("missing cluster box for \{label}")
    }
  }
}
