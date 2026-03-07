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
  // Graphviz virtual edges can carry parallel multiplicity on one edge record.
  // Our path adjacency lists parallel hops explicitly, so merge detection must
  // compare distinct predecessors/successors instead of raw multiplicity.
  let out_count = unique_count(out_raw)
  let in_count = unique_count(in_raw)
  out_count > 1 || in_count > 1
}

///|
/// Graphviz parity: recover_slack aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
pub fn recover_slack_vnodes(
  input : RecoverSlackVnodesInput,
  label_rank_for_edge : (@cgraph.Edge, Map[String, Int]) -> Int?,
) -> Unit {
  let edge = input.edge
  let ordered_vnodes = input.ordered_vnodes
  let boxes = input.boxes
  let ranks = input.ranks
  let vnode_ranks = input.vnode_ranks
  let rank_y = input.rank_y
  let vnode_positions = input.vnode_positions
  let vnode_sizes = input.vnode_sizes
  let adjacency = input.adjacency
  if ordered_vnodes.length() == 0 || boxes.length() == 0 {
    return ()
  }
  let label_rank = match (label_rank_for_edge)(edge, ranks) {
    Some(value) => value
    None => -1
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
    if vnode_rank == label_rank {
      let new_x = box.urx
      let left = new_x - box.llx
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        @node_primitives.vnode_size_from_widths_with_h(left, size.right_pt, size.height_pt)
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        @node_primitives.vnode_size_from_widths_with_h(half, half, size.height_pt)
    }
  }
}
