// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
// dotsplines.c straight_len follows the live fast graph, excluding merge and
// branch nodes even when their coordinates happen to lie on the same line.
fn straight_chain_length(
  start : String,
  positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, NodeSize],
  outgoing : Map[String, Array[String]],
  incoming : Map[String, Array[String]],
) -> Int {
  guard positions.get(start) is Some(base) else { return 0 }
  for current = start, count = 0 {
    guard outgoing.get(current) is Some(next_nodes) && next_nodes.length() > 0 else {
      break count
    }
    let next = next_nodes[0]
    guard is_virtual_node(next, vnode_sizes) &&
      path_neighbors(next, outgoing, vnode_sizes).length() == 1 &&
      path_neighbors(next, incoming, vnode_sizes).length() == 1 else {
      break count
    }
    guard positions.get(next) is Some(pos) && pos.x == base.x else {
      break count
    }
    continue next, count + 1
  }
}
