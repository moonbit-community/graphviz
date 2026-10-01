// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "render_svg emits svg" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon fill=\"lightgrey\" stroke=\"black\""))
}

///|
test "render_svg draws shapefile nodes with a box outline" {
  let graph = @dot.parse_dot(
    "digraph { a [label=\"\" shapefile=\"shape.gif\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<polygon fill=\"none\" stroke=\"black\""))
  assert_false(svg.contains("<ellipse fill=\"none\" stroke=\"black\""))
}

///|
test "render_svg preserves forestgreen label color" {
  let graph = @dot.parse_dot("digraph { a [fontcolor=forestgreen]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"forestgreen\""))
}

///|
test "render_svg preserves standard palegoldenrod color names" {
  let graph = @dot.parse_dot(
    "digraph { a [color=palegoldenrod style=filled]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"palegoldenrod\""))
  assert_true(svg.contains("stroke=\"palegoldenrod\""))
}

///|
test "render_svg emits linear gradients for multicolor node fills" {
  let graph = @dot.parse_dot(
    "digraph { a [style=filled fillcolor=\"red:blue\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<linearGradient id=\"node1_l_0\""))
  assert_true(svg.contains("stop-color:red"))
  assert_true(svg.contains("stop-color:blue"))
  assert_true(svg.contains("fill=\"url(#node1_l_0)\""))
}

///|
test "render_svg emits radial gradients for radial node styles" {
  let graph = @dot.parse_dot(
    "digraph { a [style=radial fillcolor=\"red:blue\" gradientangle=90]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<radialGradient id=\"node1_r_0\""))
  assert_true(svg.contains("fx=\"50%\" fy=\"0%\""))
  assert_true(svg.contains("stop-color:red"))
  assert_true(svg.contains("stop-color:blue"))
  assert_true(svg.contains("fill=\"url(#node1_r_0)\""))
}

///|
test "render_svg emits radial gradients for graph and cluster backgrounds" {
  let graph = @dot.parse_dot(
    "digraph { style=radial bgcolor=\"red:blue\"; subgraph cluster_0 { style=radial fillcolor=\"green:yellow\"; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("<radialGradient id=\"graph0_r_0\""))
  assert_true(svg.contains("<radialGradient id=\"clust1_r_1\""))
  assert_true(svg.contains("fill=\"url(#graph0_r_0)\""))
  assert_true(svg.contains("fill=\"url(#clust1_r_1)\""))
}

///|
test "render_svg applies labelfontcolor to endpoint labels" {
  let graph = @dot.parse_dot(
    "digraph { a -> b [headlabel=head labelfontcolor=chocolate]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">head</text>"))
  assert_true(svg.contains("fill=\"chocolate\""))
}

///|
test "render_svg skips outlines for plaintext nodes" {
  let graph = @dot.parse_dot("digraph { a [shape=plaintext,label=\"hello\"]; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
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
test "render_svg fills cluster background" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_0 { style=filled; color=lightgrey; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"lightgrey\""))
}

///|
test "render_svg hides cluster outlines with zero peripheries" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_0 { style=filled; peripheries=0; a; } }",
  )
  let svg = @svg.render_svg(@layout_dot.layout_dot(graph), options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("stroke=\"none\""))
}

///|
test "render_svg skips empty cluster outlines" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_empty { label=\"empty\"; } subgraph cluster_full { label=\"full\"; a; } }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
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
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains(">Root</text>"))
}

///|
fn normalize_text(text : String) -> String {
  let mut out = text.replace_all(old="&#45;", new="-")
  out = out.replace_all(old="&amp;", new="&")
  out = out.replace_all(old="&lt;", new="<")
  out = out.replace_all(old="&gt;", new=">")
  out = out.replace_all(old="&quot;", new="\"")
  out = out.replace_all(old="&apos;", new="'")
  out = out.replace_all(old="&#39;", new="'")
  out = out.replace_all(old="&#160;", new=" ")
  out = out.replace_all(old="&#xA0;", new=" ")
  out = out.replace_all(old="&#xa0;", new=" ")
  out.trim(chars=" \n\r\t").to_owned()
}

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
    let tag = svg.unsafe_substring(start~, end=tag_end + 1)
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
test "render_svg passes css variables through as paints" {
  let graph = @dot.parse_dot(
    "digraph { bgcolor=\"var(--uml-canvas)\"; a [style=filled, fillcolor=\"var(--uml-node)\", color=\"var(--uml-line)\", fontcolor=\"var(--uml-text)\"]; a -> b [color=\"var(--uml-line)\", label=\"edge\", fontcolor=\"var(--uml-text)\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"var(--uml-canvas)\""))
  assert_true(svg.contains("fill=\"var(--uml-node)\""))
  assert_true(svg.contains("stroke=\"var(--uml-line)\""))
  assert_true(svg.contains("fill=\"var(--uml-text)\""))
  assert_true(!svg.contains("#000000"))
}

///|
test "render_svg keeps the css variable spelling verbatim" {
  let graph = @dot.parse_dot(
    "digraph { bgcolor=\"VAR(--UML-Canvas)\"; a [style=filled, fillcolor=\"var(--x, #ff0000)\"]; }",
  )
  let layout = @layout_dot.layout_dot(graph)
  let svg = @svg.render_svg(layout, options={
    pretty: Some(false),
    include_xml_decl: Some(false),
  })
  assert_true(svg.contains("fill=\"VAR(--UML-Canvas)\""))
  assert_true(svg.contains("fill=\"var(--x, #ff0000)\""))
}
