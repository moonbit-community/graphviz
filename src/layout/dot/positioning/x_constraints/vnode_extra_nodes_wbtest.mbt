// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_vnode_extra_nodes preserves explicit vnode order before fallback entries" {
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  vnode_ranks["v2"] = 2
  vnode_ranks["v3"] = 3

  let extra = build_vnode_extra_nodes(["v2", "missing", "v1"], vnode_ranks)

  assert_eq(extra.length(), 3)
  assert_eq(extra[0].name, "v2")
  assert_eq(extra[0].rank, 2)
  assert_eq(extra[1].name, "v1")
  assert_eq(extra[1].rank, 1)
  assert_eq(extra[2].name, "v3")
  assert_eq(extra[2].rank, 3)
}
