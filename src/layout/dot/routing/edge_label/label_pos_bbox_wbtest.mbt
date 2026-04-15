// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "expand_bbox_for_label_pos only grows when both center and metrics exist" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let metrics : LabelExtent = { width: 6.0, height: 4.0 }

  let expanded = expand_bbox_for_label_pos(
    bbox,
    Some(@edge_spline.point(12.0, 5.0)),
    Some(metrics),
  )

  assert_eq(expanded, { llx: 0.0, lly: 0.0, urx: 15.0, ury: 10.0 })
  assert_eq(expand_bbox_for_label_pos(bbox, None, Some(metrics)), bbox)
  assert_eq(
    expand_bbox_for_label_pos(bbox, Some(@edge_spline.point(12.0, 5.0)), None),
    bbox,
  )
}
