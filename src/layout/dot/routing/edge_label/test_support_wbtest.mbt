// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
}

///|
fn require_point_with_tangent(
  value : PointWithTangent?,
  label : String,
) -> PointWithTangent raise {
  match value {
    Some(point) => point
    None => fail("\{label}: expected point with tangent")
  }
}

///|
fn straight_spline_points() -> Array[@geom.Point] {
  [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(3.0, 0.0),
    @edge_spline.point(6.0, 0.0),
    @edge_spline.point(9.0, 0.0),
  ]
}

///|
fn straight_spline() -> @geom.Spline {
  { start: None, end: None, points: straight_spline_points() }
}

///|
fn straight_spline_with_markers() -> @geom.Spline {
  {
    start: Some(@edge_spline.point(-1.0, 0.0)),
    end: Some(@edge_spline.point(10.0, 0.0)),
    points: straight_spline_points(),
  }
}

///|
fn layout_edge(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  label_pos? : @geom.Point? = None,
  head_label_pos? : @geom.Point? = None,
  tail_label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutEdge {
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}
