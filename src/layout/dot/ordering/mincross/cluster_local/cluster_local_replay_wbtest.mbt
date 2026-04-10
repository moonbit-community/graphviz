// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "merge_ranks_with_vnodes overlays vnode ranks without dropping base entries" {
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["b"] = 9
  vnode_ranks["v1"] = 2

  let merged = merge_ranks_with_vnodes(ranks, vnode_ranks)

  assert_eq(merged.length(), 3)
  assert_eq(merged.get("a"), Some(0))
  assert_eq(merged.get("b"), Some(9))
  assert_eq(merged.get("v1"), Some(2))
}
