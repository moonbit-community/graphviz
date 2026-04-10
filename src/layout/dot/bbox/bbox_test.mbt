// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "spline_bbox returns none for empty input and point bounds for non-bezier polylines" {
  assert_eq(spline_bbox([]), None)
  let bbox = spline_bbox([
    { x: -1.0, y: 2.0 },
    { x: 3.0, y: 4.0 },
    { x: 2.0, y: -5.0 },
  ])
  assert_eq(bbox, Some({ llx: -1.0, lly: -5.0, urx: 3.0, ury: 4.0 }))
}

///|
test "spline_bbox captures cubic bezier bulge beyond endpoints" {
  let bbox = spline_bbox([
    { x: 0.0, y: 0.0 },
    { x: 0.0, y: 10.0 },
    { x: 10.0, y: 10.0 },
    { x: 10.0, y: 0.0 },
  ])
  match bbox {
    Some(rect) => {
      assert_eq(rect.llx, 0.0)
      assert_eq(rect.lly, 0.0)
      assert_eq(rect.urx, 10.0)
      assert_true(rect.ury > 7.4)
      assert_true(rect.ury < 7.6)
    }
    None => fail("expected bezier bbox")
  }
}

///|
test "merge_bbox and round_bbox keep pure rectangle arithmetic" {
  let merged = merge_bbox({ llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 }, {
    llx: -1.0,
    lly: 3.0,
    urx: 2.0,
    ury: 10.0,
  })
  assert_eq(merged, { llx: -1.0, lly: 2.0, urx: 3.0, ury: 10.0 })

  let rounded = round_bbox({ llx: 1.2, lly: -3.4, urx: 7.8, ury: 9.9 })
  assert_eq(rounded, { llx: 1.0, lly: -3.4, urx: 8.0, ury: 9.9 })
}
