// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_x_position_solve_input toggles vnode overlays and extra nodes" {
  let with_vnodes = build_x_position_solve_input(build_simplex_test_input(true))
  let without_vnodes = build_x_position_solve_input(
    build_simplex_test_input(false),
  )
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0_1"

  assert_eq(with_vnodes.rank_keys, [0])
  assert_eq(with_vnodes.ranks.get("a"), Some(0))
  assert_eq(with_vnodes.ranks.get("b"), Some(0))
  assert_eq(with_vnodes.extra_nodes.length(), 1)
  assert_eq(with_vnodes.extra_nodes[0].name, vnode_name)
  assert_eq(with_vnodes.extra_nodes[0].rank, 1)
  let vnode_size = require_simplex_test_size(with_vnodes.sizes, vnode_name)
  assert_eq(vnode_size.left_pt, 4.0)
  assert_eq(vnode_size.right_pt, 6.0)
  assert_eq(vnode_size.height_pt, 2.0)
  assert_eq(with_vnodes.edge_vnodes.get("edge0"), Some([vnode_name]))

  assert_eq(without_vnodes.extra_nodes.length(), 0)
  assert_true(without_vnodes.sizes.get(vnode_name) is None)
  assert_eq(without_vnodes.edge_vnodes.length(), 0)
}
