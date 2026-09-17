// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "acyclic_edge_directions_for_names reverses the back edge of a cycle" {
  let directions = acyclic_edge_directions_for_names(
    ["a", "b", "c"],
    ["a", "b", "c", "b"],
    ["b", "c", "a", "b"],
    [true, true, true, true],
  )

  assert_eq(directions.tail, ["a", "b", "a", "b"])
  assert_eq(directions.head, ["b", "c", "c", "b"])
  assert_eq(directions.reversed, [false, false, true, false])
}
