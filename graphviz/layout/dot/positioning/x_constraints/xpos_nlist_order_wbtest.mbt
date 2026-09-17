// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "xpos preserves captured expansion order instead of final rank order" {
  let captured = ["v", "b", "a", "outside"]
  let order = build_xpos_nlist_order({
    nlist_order: ["a", "outside", "b", "v"],
    gdnlist_order: captured,
  })
  @test.assert_eq(order, captured)
}

///|
test "xpos uses the source list when there is no captured expansion" {
  let order = build_xpos_nlist_order({
    nlist_order: ["outside", "b", "a"],
    gdnlist_order: [],
  })
  @test.assert_eq(order, ["outside", "b", "a"])
}
