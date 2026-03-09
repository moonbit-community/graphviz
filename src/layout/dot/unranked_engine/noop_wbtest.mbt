///|
test "parse_edge_pos scales start/end markers and preserves cubic control points" {
  let splines = parse_edge_pos("s,1,2 3,4 5,6 7,8 9,10 e,11,12", 2.0)
  assert_eq(splines.length(), 1)
  let spline = splines[0]
  assert_eq(spline.start, Some({ x: 2.0, y: 4.0 }))
  assert_eq(spline.end, Some({ x: 22.0, y: 24.0 }))
  assert_eq(spline.points, [
    { x: 6.0, y: 8.0 },
    { x: 10.0, y: 12.0 },
    { x: 14.0, y: 16.0 },
    { x: 18.0, y: 20.0 },
  ])
}

///|
test "prepare_noop_layout_tree reuses edge pos when no_op_level > 1" {
  let graph = @dot_parser.parse_dot(
    "graph { node [shape=box,width=1,height=1,label=\"\"]; a [pos=\"0,0\"]; b [pos=\"100,0\"]; a -- b [pos=\"s,0,0 10,0 30,0 60,0 90,0 e,100,0\"]; }",
  )
  let layout_tree = match prepare_noop_layout_tree(graph, 2, 72.0, false) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  assert_eq(layout_tree.edges.length(), 1)
  let splines = layout_tree.edges[0].splines
  assert_eq(splines.length(), 1)
  let spline = splines[0]
  assert_eq(spline.start, Some({ x: 0.0, y: 0.0 }))
  assert_eq(spline.end, Some({ x: 100.0, y: 0.0 }))
  assert_eq(spline.points, [
    { x: 10.0, y: 0.0 },
    { x: 30.0, y: 0.0 },
    { x: 60.0, y: 0.0 },
    { x: 90.0, y: 0.0 },
  ])
}
