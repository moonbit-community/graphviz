///|
test "nudge_label_rect shifts along the lower-overlap axis and rebuilds the rect" {
  let horizontal_pos = @edge_spline.point(10.0, 10.0)
  let horizontal_rect = rect_from_center(horizontal_pos, 4.0, 4.0, 1.0)
  let horizontal = nudge_label_rect(
    horizontal_pos,
    horizontal_rect,
    { llx: 11.0, lly: 8.0, urx: 16.0, ury: 12.0 },
    4.0,
    4.0,
    1.0,
  )
  assert_point_close(horizontal.label_pos, @edge_spline.point(7.0, 10.0))
  assert_eq(
    horizontal.label_rect,
    rect_from_center(horizontal.label_pos, 4.0, 4.0, 1.0),
  )

  let vertical = nudge_label_rect(
    horizontal.label_pos,
    horizontal.label_rect,
    { llx: 6.0, lly: 11.0, urx: 9.0, ury: 16.0 },
    4.0,
    4.0,
    1.0,
  )
  assert_point_close(vertical.label_pos, @edge_spline.point(7.0, 7.0))
  assert_eq(
    vertical.label_rect,
    rect_from_center(vertical.label_pos, 4.0, 4.0, 1.0),
  )
}

///|
test "adjust_edge_label_positions applies sequential nudges and records the final update" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_pos = Some(@edge_spline.point(10.0, 10.0))
  let edge_layout = layout_edge(edge, straight_spline(), label_pos~)

  let adjusted = adjust_edge_label_positions(
    [edge_layout],
    [
      { llx: 11.0, lly: 8.0, urx: 16.0, ury: 12.0 },
      { llx: 6.0, lly: 11.0, urx: 9.0, ury: 16.0 },
    ],
    1.0,
    _ => Some({ width: 4.0, height: 4.0 }),
  )

  let expected = Some(@edge_spline.point(7.0, 7.0))
  assert_eq(adjusted.edges.length(), 1)
  assert_eq(adjusted.edges[0].label_pos, expected)
  assert_eq(adjusted.updates.get(@edge_identity.edge_key(edge)), expected)
}
