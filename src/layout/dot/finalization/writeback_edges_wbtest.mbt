///|
test "apply_layout_tree_writeback writes graph label metrics star node rounding and arrow markers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let star = graph.node("star")
  star.set_attr("shape", "star")
  let head = graph.node("head")
  let edge = graph.edge(star, head)
  edge.set_attr("dir", "both")

  let star_layout = writeback_make_node_layout(
    star,
    { x: 10.0, y: 20.0 },
    1.0,
    0.5,
  )
  let edge_layout = writeback_make_edge_layout(edge, {
    start: Some({ x: -1.0, y: -2.0 }),
    end: Some({ x: 12.0, y: 13.0 }),
    points: [
      { x: 0.0, y: 0.0 },
      { x: 2.0, y: 1.0 },
      { x: 4.0, y: 2.0 },
      { x: 6.0, y: 3.0 },
    ],
  })
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 5.0, y: 9.0 }),
    nodes=[star_layout],
    edges=[edge_layout],
  )

  apply_layout_tree_writeback(layout)

  let graph_metrics = match @label_metrics.graph_label_metrics(graph) {
    Some(value) => value
    None => fail("expected root graph label metrics")
  }
  assert_eq(
    graph.get_attr("lwidth"),
    Some(format_fixed(graph_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    graph.get_attr("lheight"),
    Some(format_fixed(graph_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(graph.get_attr("lp"), Some("5,9"))
  assert_eq(star.get_attr("pos"), Some(format_point({ x: 10.0, y: 20.0005 })))
  assert_eq(edge.get_attr("pos"), Some("s,-1,-2 e,12,13 0,0 2,1 4,2 6,3"))
}

///|
test "apply_layout_tree_writeback omits disabled arrow markers independently" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let tail_disabled = graph.edge(a, b)
  let head_disabled = graph.edge(a, b, name="head_disabled")
  tail_disabled.set_attr("dir", "both")
  tail_disabled.set_attr("arrowtail", "none")
  head_disabled.set_attr("dir", "both")
  head_disabled.set_attr("arrowhead", "none")

  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=[
      writeback_make_edge_layout(tail_disabled, {
        start: Some({ x: -1.0, y: -2.0 }),
        end: Some({ x: 12.0, y: 13.0 }),
        points: [
          { x: 0.0, y: 0.0 },
          { x: 2.0, y: 1.0 },
          { x: 4.0, y: 2.0 },
          { x: 6.0, y: 3.0 },
        ],
      }),
      writeback_make_edge_layout(head_disabled, {
        start: Some({ x: -3.0, y: -4.0 }),
        end: Some({ x: 14.0, y: 15.0 }),
        points: [
          { x: 1.0, y: 0.0 },
          { x: 3.0, y: 1.0 },
          { x: 5.0, y: 2.0 },
          { x: 7.0, y: 3.0 },
        ],
      }),
    ],
  )

  apply_layout_tree_writeback(layout)

  assert_eq(tail_disabled.get_attr("pos"), Some("e,12,13 0,0 2,1 4,2 6,3"))
  assert_eq(head_disabled.get_attr("pos"), Some("s,-3,-4 1,0 3,1 5,2 7,3"))
}
