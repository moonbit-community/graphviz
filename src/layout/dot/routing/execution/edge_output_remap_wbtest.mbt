///|
test "remap_port_label_pos respects attr gating fallback and head-tail spline selection" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let splines = [spline_with_start_x(1.0), spline_with_start_x(9.0)]
  let fallback = Some(@edge_spline.point(77.0, 0.0))

  assert_eq(
    remap_port_label_pos({
      edge,
      splines,
      label_attr: "headlabel",
      is_head: true,
      fallback,
      edge_port_label_pos_fn: _ => Some(@edge_spline.point(0.0, 0.0)),
    }),
    None,
  )

  edge.set_attr("headlabel", "h")
  assert_eq(
    remap_port_label_pos({
      edge,
      splines: [],
      label_attr: "headlabel",
      is_head: true,
      fallback,
      edge_port_label_pos_fn: _ => Some(@edge_spline.point(0.0, 0.0)),
    }),
    fallback,
  )

  let tail = remap_port_label_pos({
    edge,
    splines,
    label_attr: "headlabel",
    is_head: false,
    fallback,
    edge_port_label_pos_fn: input => Some(input.spline.points[0]),
  })
  let head = remap_port_label_pos({
    edge,
    splines,
    label_attr: "headlabel",
    is_head: true,
    fallback,
    edge_port_label_pos_fn: input => Some(input.spline.points[0]),
  })

  assert_eq(tail, Some(@edge_spline.point(1.0, 0.0)))
  assert_eq(head, Some(@edge_spline.point(9.0, 0.0)))
}

///|
test "remap_edge_layout_edge keeps only attrs present on the target edge and falls back per endpoint label" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let source_edge = graph.edge(graph.node("a"), graph.node("b"))
  let target_edge = graph.edge(graph.node("a"), graph.node("b"), name="target")
  target_edge.set_attr("headlabel", "head")
  target_edge.set_attr("taillabel", "tail")
  target_edge.set_attr("xlabel", "x")

  let layout = build_layout_edge(
    source_edge,
    12.0,
    label_pos=Some(@edge_spline.point(1.0, 1.0)),
    head_label_pos=Some(@edge_spline.point(2.0, 2.0)),
    tail_label_pos=Some(@edge_spline.point(3.0, 3.0)),
    xlabel_pos=Some(@edge_spline.point(4.0, 4.0)),
  )

  let remapped = remap_edge_layout_edge(target_edge, layout, input => {
    if input.is_head {
      Some(@edge_spline.point(100.0, input.spline.points[0].x))
    } else {
      None
    }
  })

  assert_eq(remapped.edge.id(), target_edge.id())
  assert_eq(remapped.splines, layout.splines)
  assert_eq(remapped.label_pos, None)
  assert_eq(remapped.head_label_pos, Some(@edge_spline.point(100.0, 12.0)))
  assert_eq(remapped.tail_label_pos, layout.tail_label_pos)
  assert_eq(remapped.xlabel_pos, layout.xlabel_pos)
}
