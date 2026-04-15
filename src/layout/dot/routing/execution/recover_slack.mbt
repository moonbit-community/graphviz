// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn vnode_is_merged(
  name : String,
  adjacency : @routesplines.PathAdjacency,
) -> Bool {
  let out_raw = match adjacency.out_edges.get(name) {
    Some(list) => list
    None => []
  }
  let in_raw = match adjacency.in_edges.get(name) {
    Some(list) => list
    None => []
  }
  let unique_count = (list : Array[String]) => {
    let seen : Map[String, Bool] = Map::new()
    let mut count = 0
    for item in list {
      if seen.get(item) is None {
        seen[item] = true
        count = count + 1
      }
    }
    count
  }
  unique_count(out_raw) > 1 || unique_count(in_raw) > 1
}

///|
/// Graphviz parity: only the dedicated label vnode (ND_label(vn)) is
/// right-aligned during recover_slack. In our vnode model that is the virtual
/// node whose height exceeds the plain virtual-node height.
fn vnode_is_label_vnode(
  name : String,
  vnode_sizes : Map[String, @node_primitives.NodeSize],
) -> Bool {
  match vnode_sizes.get(name) {
    Some(size) => size.height_pt > @node_primitives.VNODE_HEIGHT_PT
    None => false
  }
}

///|
/// Graphviz parity: recover_slack aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
pub fn recover_slack_vnodes(input : RecoverSlackVnodesInput) -> Unit {
  let ordered_vnodes = input.ordered_vnodes
  let boxes = input.boxes
  let vnode_ranks = input.vnode_ranks
  let rank_y = input.rank_y
  let vnode_positions = input.vnode_positions
  let vnode_sizes = input.vnode_sizes
  let merged_positions = input.merged_positions
  let pathplan_route_sizes = input.pathplan_route_sizes
  let adjacency = input.adjacency
  if ordered_vnodes.length() == 0 || boxes.length() == 0 {
    return ()
  }
  let mut box_idx = 0
  for vnode in ordered_vnodes {
    if vnode_is_merged(vnode, adjacency) {
      break
    }
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let vnode_y = match rank_y.get(vnode_rank) {
      Some(value) => value
      None => continue
    }
    while box_idx < boxes.length() && boxes[box_idx].lly > vnode_y {
      box_idx = box_idx + 1
    }
    if box_idx >= boxes.length() {
      break
    }
    let box = boxes[box_idx]
    if box.ury < vnode_y {
      continue
    }
    let size = match vnode_sizes.get(vnode) {
      Some(value) => value
      None => continue
    }
    if vnode_is_label_vnode(vnode, vnode_sizes) {
      let new_x = box.urx
      let left = new_x - box.llx
      let new_pos : @geom.Point = { x: new_x, y: vnode_y }
      let new_size = @node_primitives.vnode_size_from_widths_with_h(
        left,
        size.right_pt,
        size.height_pt,
      )
      vnode_positions[vnode] = new_pos
      vnode_sizes[vnode] = new_size
      merged_positions[vnode] = new_pos
      pathplan_route_sizes[vnode] = new_size
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      let new_pos : @geom.Point = { x: new_x, y: vnode_y }
      let new_size = @node_primitives.vnode_size_from_widths_with_h(
        half,
        half,
        size.height_pt,
      )
      vnode_positions[vnode] = new_pos
      vnode_sizes[vnode] = new_size
      merged_positions[vnode] = new_pos
      pathplan_route_sizes[vnode] = new_size
    }
  }
}
