///|
/// Edge-label rank/vnode helpers aligned with Graphviz dotsplines label flows.

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> EdgeLabelRankInfo? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some({ label_rank, span })
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some(info) => rank_y.get(info.label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
/// Graphviz parity: label vnode offset aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// (place_vnlabel, GD_flip).
/// Do not change behavior without updating fixtures/tests.
fn edge_label_pos_from_vnode(
  vnode_pos : @geom.Point,
  label_width_pt : Double,
  label_height_pt : Double,
  rankdir : RankDir,
) -> @geom.Point {
  let width =
    if rankdir == RankDir::LR || rankdir == RankDir::RL {
      label_height_pt
    } else {
      label_width_pt
    }
  @edge_spline.point(vnode_pos.x + width / 2.0, vnode_pos.y)
}

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
fn recover_slack_vnodes(
  input : @routing.RecoverSlackVnodesInput,
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
  let label_rank = match edge_label_rank_info(edge, ranks) {
    Some(info) => info.label_rank
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
        vnode_size_from_widths_with_h(left, size.right_pt, size.height_pt)
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        vnode_size_from_widths_with_h(half, half, size.height_pt)
    }
  }
}
