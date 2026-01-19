///|
test "encode xdot ops basic" {
  let ops : Array[@render.DrawOp] = [
    @render.DrawOp::PenColor(color="black"),
    @render.DrawOp::Ellipse(
      filled=true,
      rect={ llx: 0.0, lly: 0.0, urx: 10.0, ury: 20.0 },
    ),
    @render.DrawOp::Text(
      pos={ x: 5.0, y: 6.0 },
      align=@render.TextAlign::Center,
      width=12.0,
      text="Hi",
    ),
  ]
  inspect(encode_xdot_ops(ops), content="c 5 -black E 5 10 5 10 T 5 6 0 12 2 -Hi")
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
  guard edges.length() > 0 else {
    fail("missing edges")
  }
  let edge = edges[0]
  guard edge.get_attr("_draw_") is Some(_) else {
    fail("missing edge _draw_")
  }
}
