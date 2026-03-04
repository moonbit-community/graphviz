///|
/// Rank-based bbox helper shared by routing precompute and final geometry.

///|
/// Graphviz parity: rank-based bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn compute_dot_bbox(
  nodes_out : Array[DotLayoutNode],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> @geom.Rect {
  if nodes_out.length() == 0 {
    return { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut first = true
  for node_layout in nodes_out {
    let name = node_layout.node.name()
    let left = node_left_pt(name, sizes)
    let right = node_right_pt(name, sizes)
    let llx = node_layout.pos.x - left
    let urx = node_layout.pos.x + right
    if first {
      min_x = llx
      max_x = urx
      first = false
    } else {
      if llx < min_x { min_x = llx }
      if urx > max_x { max_x = urx }
    }
  }
  let mut min_y = 0.0
  let mut max_y = 0.0
  if all_ranks.length() > 0 {
    let min_rank = all_ranks[0]
    let max_rank = all_ranks[all_ranks.length() - 1]
    let max_rank_y = match rank_y.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let min_rank_y = match rank_y.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht1 = match rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    let ht2 = match rank_ht2.get(min_rank) {
      Some(value) => value
      None => 0.0
    }
    min_y = max_rank_y - ht1
    max_y = min_rank_y + ht2
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}

