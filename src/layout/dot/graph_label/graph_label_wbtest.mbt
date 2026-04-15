// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
    graph_label_pos(bbox, width, height, LabelLoc::Top, LabelJust::Left),
    { x: 20.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos(bbox, width, height, LabelLoc::Top, LabelJust::Center),
    { x: 60.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos(bbox, width, height, LabelLoc::Top, LabelJust::Right),
    { x: 100.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos(bbox, width, height, LabelLoc::Bottom, LabelJust::Left),
    { x: 20.0, y: 25.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos(bbox, width, height, LabelLoc::Bottom, LabelJust::Center),
    { x: 60.0, y: 25.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos(bbox, width, height, LabelLoc::Bottom, LabelJust::Right),
    { x: 100.0, y: 25.0 },
  )
}

///|
test "graph label attribute parsing and inheritance follow graph role defaults" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("labeljust", "l")
  let cluster = root.subgraph(name="cluster_0")
  let plain = root.subgraph(name="group_0")
  plain.set_attr("labelloc", "bottom")
  cluster.set_attr("labeljust", "r")

  guard parse_label_loc(Some("TOP"), LabelLoc::Bottom) is LabelLoc::Top else {
    fail("expected top label loc")
  }
  guard parse_label_loc(Some("b"), LabelLoc::Top) is LabelLoc::Bottom else {
    fail("expected bottom label loc")
  }
  guard parse_label_loc(Some("unknown"), LabelLoc::Bottom) is LabelLoc::Bottom else {
    fail("expected default label loc")
  }
  guard parse_label_just(Some("r")) is LabelJust::Right else {
    fail("expected right label just")
  }
  guard parse_label_just(Some("bogus")) is LabelJust::Center else {
    fail("expected center label just fallback")
  }

  assert_eq(graph_attr_inherited(cluster, "labeljust"), Some("r"))
  assert_eq(graph_attr_inherited(plain, "labeljust"), Some("l"))
  guard graph_label_loc(root) is LabelLoc::Bottom else {
    fail("root graphs default to bottom labels")
  }
  guard graph_label_loc(cluster) is LabelLoc::Top else {
    fail("cluster graphs default to top labels")
  }
  guard graph_label_loc(plain) is LabelLoc::Bottom else {
    fail("plain override should win")
  }
  guard graph_label_just(cluster) is LabelJust::Right else {
    fail("cluster override should win")
  }
  guard graph_label_just(plain) is LabelJust::Left else {
    fail("plain graph should inherit left justification")
  }
}

///|
test "graph_label_metrics_with uses inherited graph font attrs and skips empty labels" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("fontname", "Courier")
  root.set_attr("fontsize", "14")
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "abc")
  let empty = root.subgraph(name="cluster_1")
  empty.set_attr("label", "")

  let metrics = match
    graph_label_metrics_with(cluster, (label, font, size) => {
      (
        label.length().to_double() * size + font.length().to_double(),
        size + 2.0,
      )
    }) {
    Some(value) => value
    None => fail("expected graph label metrics")
  }

  assert_eq(metrics.width_pt, 49.0)
  assert_eq(metrics.height_pt, 16.0)
  assert_true(
    graph_label_metrics_with(empty, (_label, _font, _size) => (0.0, 0.0))
    is None,
  )
}

///|
test "graph_label_pos_flip and expand_bbox_for_label match Graphviz border rules" {
  let bbox : @geom.Rect = { llx: 10.0, lly: 20.0, urx: 110.0, ury: 70.0 }
  let width = 20.0
  let height = 10.0

  assert_label_pos_point_eq(
    graph_label_pos_flip(bbox, width, height, LabelLoc::Top, LabelJust::Left),
    { x: 100.0, y: 65.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos_flip(
      bbox,
      width,
      height,
      LabelLoc::Bottom,
      LabelJust::Right,
    ),
    { x: 20.0, y: 25.0 },
  )
  assert_label_pos_point_eq(
    graph_label_pos_flip(bbox, width, height, LabelLoc::Top, LabelJust::Center),
    { x: 100.0, y: 45.0 },
  )

  let expanded_top = expand_bbox_for_label(
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    20.0,
    5.0,
    LabelLoc::Top,
  )
  assert_eq(expanded_top, { llx: -13.0, lly: 0.0, urx: 23.0, ury: 23.0 })

  let expanded_bottom = expand_bbox_for_label(
    { llx: 0.0, lly: 0.0, urx: 30.0, ury: 10.0 },
    10.0,
    5.0,
    LabelLoc::Bottom,
  )
  assert_eq(expanded_bottom, { llx: 0.0, lly: -13.0, urx: 30.0, ury: 10.0 })
}
