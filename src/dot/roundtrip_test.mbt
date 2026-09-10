// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "write_dot omits implicit node label defaults" {
  let graph = try @dot.parse_dot("digraph { a }") catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(!output.contains("label=\"\\N\""))
}

///|
test "parser removes escaped quoted-string line continuations" {
  let source = "digraph { a [label=\"left\\" + "\n" + "right\\nend\"]; }"
  let graph = try @dot.parse_dot(source) catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }

  assert_eq(graph.node("a").get_attr("label"), Some("leftright\\nend"))
}

///|
test "parser promotes tailport and headport attrs to edge ports" {
  let graph = try
    @dot.parse_dot("digraph { a -> a [tailport=se, headport=se]; }")
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let edges = graph.edges()
  assert_eq(edges.length(), 1)
  let edge = edges[0]
  assert_eq(edge.tail_port(), Some({ name: None, compass: Some(SE), }))
  assert_eq(edge.head_port(), Some({ name: None, compass: Some(SE), }))
  assert_eq(edge.get_attr("tailport"), None)
  assert_eq(edge.get_attr("headport"), None)
  let output = @dot.write_dot(graph)
  assert_true(output.contains("a:se -> a:se"))
  assert_false(output.contains("tailport="))
  assert_false(output.contains("headport="))
}

///|
test "write_dot orders edge clip attrs around generated position" {
  let graph = try
    @dot.parse_dot(
      "digraph { a -> b [tailclip=false, headclip=false, pos=\"1,2 3,4\"]; }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let headclip_index = match output.find("headclip=false") {
    Some(value) => value
    None => fail("missing headclip attr: \{output}")
  }
  let pos_index = match output.find("pos=\"1,2 3,4\"") {
    Some(value) => value
    None => fail("missing pos attr: \{output}")
  }
  let tailclip_index = match output.find("tailclip=false") {
    Some(value) => value
    None => fail("missing tailclip attr: \{output}")
  }
  assert_true(headclip_index < pos_index)
  assert_true(pos_index < tailclip_index)
}

///|
test "write_dot orders graph peripheries before style" {
  let graph = try
    @dot.parse_dot(
      "digraph { subgraph cluster_0 { fillcolor=red; style=filled; peripheries=0; a; } }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let fillcolor_index = match output.find("fillcolor=red") {
    Some(value) => value
    None => fail("missing fillcolor attr: \{output}")
  }
  let peripheries_index = match output.find("peripheries=0") {
    Some(value) => value
    None => fail("missing peripheries attr: \{output}")
  }
  let style_index = match output.find("style=filled") {
    Some(value) => value
    None => fail("missing style attr: \{output}")
  }
  assert_true(fillcolor_index < peripheries_index)
  assert_true(peripheries_index < style_index)
}

///|
test "write_dot preserves graph attr scope for earlier subgraphs" {
  let graph = try
    @dot.parse_dot("graph G { { a; } label=\"root\"; fontsize=20; }")
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(output.contains("graph [fontsize=\"\""))
  assert_true(output.contains("label=\"\""))
}

///|
test "write_dot skips graph attr resets for later subgraphs" {
  let graph = try
    @dot.parse_dot("graph G { label=\"root\"; fontsize=20; { a; } }")
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  assert_true(!output.contains("graph [fontsize=\"\""))
  assert_true(!output.contains("graph [label=\"\""))
}

///|
test "write_dot keeps image before generated node geometry attrs" {
  let graph = try
    @dot.parse_dot(
      "digraph { a [height=0.5, pos=\"1,2\", width=0.75, image=\"usershape.svg\"]; }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let image_index = match output.find("image=\"usershape.svg\"") {
    Some(value) => value
    None => fail("missing image attr: \{output}")
  }
  let pos_index = match output.find("pos=\"1,2\"") {
    Some(value) => value
    None => fail("missing pos attr: \{output}")
  }
  let width_index = match output.find("width=0.75") {
    Some(value) => value
    None => fail("missing width attr: \{output}")
  }
  assert_true(image_index < pos_index)
  assert_true(image_index < width_index)
}

///|
test "write_dot orders gradientangle with its fill attributes" {
  let graph = try
    @dot.parse_dot(
      "digraph { bgcolor=\"yellow:blue\" gradientangle=60 label=Graph; a [fillcolor=\"red:blue\" gradientangle=180 height=1]; }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let bgcolor_index = match output.find("bgcolor=\"yellow:blue\"") {
    Some(value) => value
    None => fail("missing graph bgcolor: \{output}")
  }
  let graph_gradient_index = match output.find("gradientangle=60") {
    Some(value) => value
    None => fail("missing graph gradientangle: \{output}")
  }
  let label_index = match output.find("label=\"Graph\"") {
    Some(value) => value
    None => fail("missing graph label: \{output}")
  }
  let fill_index = match output.find("fillcolor=\"red:blue\"") {
    Some(value) => value
    None => fail("missing node fillcolor: \{output}")
  }
  let node_gradient_index = match output.find("gradientangle=180") {
    Some(value) => value
    None => fail("missing node gradientangle: \{output}")
  }
  let height_index = match output.find("height=1") {
    Some(value) => value
    None => fail("missing node height: \{output}")
  }
  assert_true(bgcolor_index < graph_gradient_index)
  assert_true(graph_gradient_index < label_index)
  assert_true(fill_index < node_gradient_index)
  assert_true(node_gradient_index < height_index)
}

///|
test "write_dot places shapefile before generated node width" {
  let graph = try
    @dot.parse_dot(
      "digraph { a [height=0.5, width=0.75, shapefile=\"shape.gif\"]; }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let shapefile_index = match output.find("shapefile=\"shape.gif\"") {
    Some(value) => value
    None => fail("missing shapefile attr: \{output}")
  }
  let width_index = match output.find("width=0.75") {
    Some(value) => value
    None => fail("missing width attr: \{output}")
  }
  assert_true(shapefile_index < width_index)
}

///|
test "parser keeps duplicate cluster node membership on first cluster only" {
  let graph = try
    @dot.parse_dot(
      "digraph { subgraph cluster_1 { 1; } subgraph cluster_2 { 1 } }",
    )
  catch {
    err => fail("parse_dot failed: \{err}")
  } noraise {
    graph => graph
  }
  let output = @dot.write_dot(graph)
  let start = match output.find("subgraph cluster_2 {") {
    Some(value) => value
    None => fail("missing cluster_2: \{output}")
  }
  let tail = output.unsafe_substring(start~, end=output.length())
  let close = match tail.find("}") {
    Some(value) => value
    None => fail("unterminated cluster_2 block: \{output}")
  }
  let cluster_block = tail.unsafe_substring(start=0, end=close + 1)
  assert_true(!cluster_block.contains("1;"))
}
