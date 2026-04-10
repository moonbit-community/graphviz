// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn make_label(target : XLabelTarget, width : Double, height : Double) -> XLabel {
  { target, width, height, pos: @edge_spline.point(0.0, 0.0), set: false }
}

///|
fn make_object(
  pos : @geom.Point,
  width : Double,
  height : Double,
  label_index? : Int? = None,
) -> XObject {
  { pos, width, height, label_index }
}

///|
fn crowded_case() -> (Array[XObject], Array[XLabel]) {
  let labels : Array[XLabel] = [make_label(XLabelTarget::Node("n"), 6.0, 4.0)]
  let objects : Array[XObject] = [
    make_object(@edge_spline.point(10.0, 10.0), 8.0, 4.0, label_index=Some(0)),
    make_object(@edge_spline.point(1.0, 1.0), 40.0, 30.0),
  ]
  (objects, labels)
}

///|
test "place_labels uses the top-left candidate when it is immediately collision free" {
  let labels : Array[XLabel] = [make_label(XLabelTarget::Node("n"), 4.0, 2.0)]
  let objects : Array[XObject] = [
    make_object(@edge_spline.point(10.0, 10.0), 6.0, 4.0, label_index=Some(0)),
  ]

  place_labels(objects, labels, false)

  assert_eq(labels[0].set, true)
  assert_eq(labels[0].pos, @edge_spline.point(6.0, 14.0))
  assert_eq(xlabel_center(labels[0]), @edge_spline.point(8.0, 15.0))
}

///|
test "place_labels only applies a positive-overlap best position when force is enabled" {
  let (probe_objects, probe_labels) = crowded_case()
  let best = xladjust(probe_objects, probe_labels, 0)
  assert_true(best.n > 0)
  assert_true(best.area > 0.0)

  let (free_objects, free_labels) = crowded_case()
  place_labels(free_objects, free_labels, false)
  assert_eq(free_labels[0].set, false)

  let (forced_objects, forced_labels) = crowded_case()
  place_labels(forced_objects, forced_labels, true)
  assert_eq(forced_labels[0].set, true)
  assert_eq(forced_labels[0].pos, best.pos)
}
