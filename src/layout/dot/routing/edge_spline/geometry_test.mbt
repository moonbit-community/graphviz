// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "point helpers compute expected values" {
  let a = point(1.0, 2.0)
  let b = point(3.0, 4.0)
  assert_eq(point_add(a, b), { x: 4.0, y: 6.0 })
  assert_eq(point_sub(b, a), { x: 2.0, y: 2.0 })
  assert_eq(point_scale(a, 2.0), { x: 2.0, y: 4.0 })
  assert_eq(point_dist2(a, b), 8.0)
  assert_eq(point_lerp(a, b, 0.5), { x: 2.0, y: 3.0 })
  assert_eq(point_dist(a, a), 0.0)
}
