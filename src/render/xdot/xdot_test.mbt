///|
test "encode xdot ops basic" {
  let ops : Array[@render.DrawOp] = [
    @render.DrawOp::PenColor(color="black"),
    @render.DrawOp::Ellipse(filled=true, rect={
      llx: 0.0,
      lly: 0.0,
      urx: 10.0,
      ury: 20.0,
    }),
    @render.DrawOp::Text(
      pos={ x: 5.0, y: 6.0 },
      align=@render.TextAlign::Center,
      width=12.0,
      text="Hi",
    ),
  ]
  inspect(
    encode_xdot_ops(ops),
    content="c 7 -#000000 E 5 10 5 10 T 5 6 0 12 2 -Hi",
  )
}

///|
test "encode xdot ops rounds doubles" {
  let ops : Array[@render.DrawOp] = [
    @render.DrawOp::Polyline(points=[
      { x: 1.239, y: 5.0 },
      { x: -2.341, y: 0.0 },
    ]),
  ]
  inspect(encode_xdot_ops(ops), content="L 2 1.24 5 -2.34 0")
}

///|
test "render_xdot attaches draw ops" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let output = render_xdot(layout)
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  guard node_a.get_attr("_draw_") is Some(_) else {
    fail("missing node _draw_")
  }
  guard output_graph.get_attr("xdotversion") is Some("1.7") else {
    fail("missing xdotversion")
  }
  let edges = output_graph.edges()
  guard edges.length() > 0 else { fail("missing edges") }
  let edge = edges[0]
  guard edge.get_attr("_draw_") is Some(_) else { fail("missing edge _draw_") }
  guard edge.get_attr("_hdraw_") is Some(_) else {
    fail("missing edge _hdraw_")
  }
}

///|
fn parse_double_or_fail(value : StringView) -> Double raise {
  @strconv.parse_double(value) catch {
    _ => fail("invalid number: \{value}")
  }
}

///|
fn parse_point_attr(value : String) -> @geom.Point raise {
  let parts = value.split(",").to_array()
  if parts.length() != 2 {
    fail("invalid point: \{value}")
  }
  { x: parse_double_or_fail(parts[0]), y: parse_double_or_fail(parts[1]) }
}

///|
fn find_subgraph(graph : @cgraph.Graph, name : String) -> @cgraph.Graph raise {
  for subgraph in graph.subgraphs() {
    match subgraph.name() {
      Some(value) => if value == name { return subgraph }
      None => ()
    }
  }
  fail("missing subgraph: \{name}")
}

///|
test "render_xdot attaches graph label attrs" {
  let graph = @dot.parse_dot("digraph { label=\"Hello\"; a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let output = render_xdot(layout)
  let output_graph = @dot.parse_dot(output)
  guard output_graph.get_attr("_ldraw_") is Some(_) else {
    fail("missing graph _ldraw_")
  }
  guard output_graph.get_attr("lwidth") is Some(_) else {
    fail("missing graph lwidth")
  }
  guard output_graph.get_attr("lheight") is Some(_) else {
    fail("missing graph lheight")
  }
  match output_graph.get_attr("lp") {
    Some(value) => {
      let _ = parse_point_attr(value)

    }
    None => fail("missing graph lp")
  }
}

///|
test "render_xdot fills cluster background" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_0 { style=filled; color=lightgrey; a; } }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let cluster = find_subgraph(output_graph, "cluster_0")
  let draw = match cluster.get_attr("_draw_") {
    Some(value) => value
    None => fail("missing cluster _draw_")
  }
  assert_true(draw.contains("-#d3d3d3"))
  assert_true(draw.contains("P "))
}

///|
test "render_xdot skips empty cluster draw ops" {
  let graph = @dot.parse_dot(
    "digraph { subgraph cluster_empty { label=\"empty\"; } subgraph cluster_full { label=\"full\"; a; } }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  guard !output.contains("subgraph cluster_empty {\n\t\tgraph [_draw_=") else {
    fail("empty cluster should not have _draw_")
  }
  guard output.contains("subgraph cluster_full {\n\t\tgraph [_draw_=") else {
    fail("non-empty cluster should have _draw_")
  }
}

///|
test "render_xdot encodes dashed and dotted styles" {
  let graph = @dot.parse_dot(
    "digraph { node [style=dashed]; a; b; a -> b [style=dotted]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let node_draw = match node_a.get_attr("_draw_") {
    Some(value) => value
    None => fail("missing node _draw_")
  }
  assert_true(node_draw.contains("S 6 -dashed"))
  let edges = output_graph.edges()
  guard edges.length() > 0 else { fail("missing edge") }
  let edge_draw = match edges[0].get_attr("_draw_") {
    Some(value) => value
    None => fail("missing edge _draw_")
  }
  assert_true(edge_draw.contains("S 6 -dotted"))
}

///|
test "render_xdot draws polygon node shapes" {
  let graph = @dot.parse_dot(
    "digraph { a [shape=diamond]; b [shape=triangle]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let node_b = match output_graph.find_node("b") {
    Some(node) => node
    None => fail("missing node b")
  }
  let draw_a = match node_a.get_attr("_draw_") {
    Some(value) => value
    None => fail("missing node _draw_")
  }
  let draw_b = match node_b.get_attr("_draw_") {
    Some(value) => value
    None => fail("missing node _draw_")
  }
  assert_true(draw_a.contains("P ") || draw_a.contains("p "))
  assert_true(!draw_a.contains("E "))
  assert_true(draw_b.contains("P ") || draw_b.contains("p "))
  assert_true(!draw_b.contains("E "))
}

///|
test "render_xdot falls back unknown node shapes to box draw ops" {
  let graph = @dot.parse_dot(
    "digraph { a [style=filled shape=DFDbox]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let draw = match node_a.get_attr("_draw_") {
    Some(value) => value
    None => fail("missing node _draw_")
  }
  assert_true(draw.contains("P 4 "))
  assert_true(draw.contains("-#d3d3d3"))
}

///|
test "render_xdot resolves forestgreen label color" {
  let graph = @dot.parse_dot("digraph { a [fontcolor=forestgreen]; }")
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let ldraw = match node_a.get_attr("_ldraw_") {
    Some(value) => value
    None => fail("missing node _ldraw_")
  }
  assert_true(ldraw.contains("-#228b22"))
}

///|
test "render_xdot renders nested record labels" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=record]; a [label=\"{a|{b|<here>c|d}|e}\"]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let label_draw = match node_a.get_attr("_ldraw_") {
    Some(value) => value
    None => fail("missing node _ldraw_")
  }
  assert_true(label_draw.contains(" -a"))
  assert_true(label_draw.contains(" -b"))
  assert_true(label_draw.contains(" -c"))
  assert_true(label_draw.contains(" -d"))
  assert_true(label_draw.contains(" -e"))
}

///|
test "render_xdot renders html-like labels" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\"><TR><TD>left</TD><TD>right</TD></TR></TABLE>>]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let label_draw = match node_a.get_attr("_ldraw_") {
    Some(value) => value
    None => fail("missing node _ldraw_")
  }
  assert_true(label_draw.contains(" -left"))
  assert_true(label_draw.contains(" -right"))
}

///|
test "render_xdot renders html label colors and nested tables" {
  let graph = @dot.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE BORDER=\\\"1\\\" CELLBORDER=\\\"1\\\" CELLSPACING=\\\"0\\\" BGCOLOR=\\\"yellow\\\"><TR><TD ALIGN=\\\"left\\\" BGCOLOR=\\\"red\\\">left</TD><TD ALIGN=\\\"right\\\">right</TD></TR><TR><TD COLSPAN=\\\"2\\\"><TABLE><TR><TD>inner</TD></TR></TABLE></TD></TR></TABLE>>]; }",
  )
  let output = render_xdot(@layout_dot.layout_dot(graph))
  let output_graph = @dot.parse_dot(output)
  let node_a = match output_graph.find_node("a") {
    Some(node) => node
    None => fail("missing node a")
  }
  let label_draw = match node_a.get_attr("_ldraw_") {
    Some(value) => value
    None => fail("missing node _ldraw_")
  }
  let normalized =
    label_draw
      .replace_all(old="\\\r\n", new="")
      .replace_all(old="\\\n", new="")
      .replace_all(old="\\\r", new="")
  assert_true(normalized.contains(" -left"))
  assert_true(normalized.contains(" -right"))
  assert_true(normalized.contains(" -inner"))
  assert_true(normalized.contains("-#ffff00"))
  assert_true(normalized.contains("-#ff0000"))
  assert_true(normalized.contains("P "))
  assert_true(normalized.contains("p "))
}

///|
test "graph labelloc affects label position" {
  let top_graph = @dot.parse_dot(
    "digraph { label=\"Hello\"; labelloc=t; a -> b; }",
  )
  let bottom_graph = @dot.parse_dot(
    "digraph { label=\"Hello\"; labelloc=b; a -> b; }",
  )
  let top_output = render_xdot(@layout_dot.layout_dot(top_graph))
  let bottom_output = render_xdot(@layout_dot.layout_dot(bottom_graph))
  let top_lp = match @dot.parse_dot(top_output).get_attr("lp") {
    Some(value) => parse_point_attr(value)
    None => fail("missing top graph lp")
  }
  let bottom_lp = match @dot.parse_dot(bottom_output).get_attr("lp") {
    Some(value) => parse_point_attr(value)
    None => fail("missing bottom graph lp")
  }
  assert_true(top_lp.y > bottom_lp.y)
}

///|
test "graph labeljust affects label position" {
  let left_graph = @dot.parse_dot(
    "digraph { label=\"Hello\"; labeljust=l; a -> b; }",
  )
  let right_graph = @dot.parse_dot(
    "digraph { label=\"Hello\"; labeljust=r; a -> b; }",
  )
  let left_output = render_xdot(@layout_dot.layout_dot(left_graph))
  let right_output = render_xdot(@layout_dot.layout_dot(right_graph))
  let left_lp = match @dot.parse_dot(left_output).get_attr("lp") {
    Some(value) => parse_point_attr(value)
    None => fail("missing left graph lp")
  }
  let right_lp = match @dot.parse_dot(right_output).get_attr("lp") {
    Some(value) => parse_point_attr(value)
    None => fail("missing right graph lp")
  }
  assert_true(left_lp.x < right_lp.x)
}
