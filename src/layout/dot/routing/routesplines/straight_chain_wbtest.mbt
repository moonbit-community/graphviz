// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "straight chains count merged parallel segments once and stop before real nodes" {
  let size = @node_primitives.vnode_size_from_widths(1.0, 1.0)
  @test.assert_eq(
    straight_chain_length(
      "v0",
      {
        "v0": { x: 10.0, y: 30.0, },
        "v1": { x: 10.0, y: 20.0, },
        "v2": { x: 10.0, y: 10.0, },
        "end": { x: 10.0, y: 0.0, },
      },
      { "v0": size, "v1": size, "v2": size },
      { "v0": ["v1", "v1"], "v1": ["v2", "v2"], "v2": ["end", "end"] },
      { "v1": ["v0", "v0"], "v2": ["v1", "v1"], "end": ["v2", "v2"] },
    ),
    2,
  )
}

///|
test "straight chains stop before a virtual merge or branch" {
  let size = @node_primitives.vnode_size_from_widths(1.0, 1.0)
  let positions : Map[String, @geom.Point] = {
    "v0": { x: 10.0, y: 30.0, },
    "v1": { x: 10.0, y: 20.0, },
  }
  let sizes = { "v0": size, "v1": size }
  @test.assert_eq(
    straight_chain_length(
      "v0",
      positions,
      sizes,
      { "v0": ["v1"], "v1": ["end"] },
      { "v1": ["v0", "other"] },
    ),
    0,
  )
  @test.assert_eq(
    straight_chain_length(
      "v0",
      positions,
      sizes,
      { "v0": ["v1"], "v1": ["end", "other"] },
      { "v1": ["v0"] },
    ),
    0,
  )
}

///|
test "straight chains require exact X alignment after slack recovery" {
  let size = @node_primitives.vnode_size_from_widths(1.0, 1.0)
  @test.assert_eq(
    straight_chain_length(
      "v0",
      { "v0": { x: 10.0, y: 30.0, }, "v1": { x: 10.001, y: 20.0, } },
      { "v0": size, "v1": size },
      { "v0": ["v1"], "v1": ["end"] },
      { "v1": ["v0"] },
    ),
    0,
  )
}
