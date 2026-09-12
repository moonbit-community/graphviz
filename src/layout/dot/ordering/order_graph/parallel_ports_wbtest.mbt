// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "coalescing distinguishes port coordinates with identical angular orders" {
  let entries = [
    ("a", "b", 1, true, 10.0, 0.0, 0.75, 0.5),
    ("a", "b", 2, true, 20.0, 0.0, 0.75, 0.5),
    ("a", "b", 3, true, 10.0, 0.0, 0.75, 0.5),
  ]
  let merged = coalesce_order_edges_by_tail({ "a": entries })
  @test.assert_eq(merged["a"].length(), 2)
  @test.assert_eq(merged["a"][0].2, 4)
  @test.assert_eq(merged["a"][1].2, 2)
  let retained = coalesce_order_edges_by_tail({ "a": entries }, should_merge=(
    _,
    _,
  ) => false)
  @test.assert_eq(retained["a"], entries)
}
