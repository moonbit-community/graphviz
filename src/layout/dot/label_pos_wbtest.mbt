///|
fn assert_label_pos_point_eq(
  actual : @geom.Point,
  expected : @geom.Point,
) -> Unit raise {
  assert_eq(actual.x, expected.x)
  assert_eq(actual.y, expected.y)
}

///|
test "graph_label_pos matches Graphviz place_root_label" {
  let bbox : @geom.Rect = { llx: 10.0, lly: 20.0, urx: 110.0, ury: 70.0 }
  let width = 20.0
  let height = 10.0
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Top,
      LabelJust::Left,
    ),
    { x: 20.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Top,
      LabelJust::Center,
    ),
    { x: 60.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Top,
      LabelJust::Right,
    ),
    { x: 100.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Bottom,
      LabelJust::Left,
    ),
    { x: 20.0, y: 25.0 },
  )
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Bottom,
      LabelJust::Center,
    ),
    { x: 60.0, y: 25.0 },
  )
  assert_label_pos_point_eq(
    @dot_shared.graph_label_pos(
      bbox,
      width,
      height,
      LabelLoc::Bottom,
      LabelJust::Right,
    ),
    { x: 100.0, y: 25.0 },
  )
}
