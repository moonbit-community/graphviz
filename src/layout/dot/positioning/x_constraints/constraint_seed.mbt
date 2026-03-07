///|
fn round_int_for_seed(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
fn nodesep_minlen_for_seed(
  tail_name : String,
  head_name : String,
  sizes : Map[String, @node_primitives.NodeSize],
  nodesep_pt : Double,
) -> Int {
  let tail_size = sizes.get(tail_name)
  let head_size = sizes.get(head_name)
  let tail_right = match tail_size {
    Some(value) => value.right_pt
    None => @node_primitives.default_node_width_in() * 72.0 / 2.0
  }
  let head_left = match head_size {
    Some(value) => value.left_pt
    None => @node_primitives.default_node_width_in() * 72.0 / 2.0
  }
  let minlen = tail_right + head_left + nodesep_pt
  if minlen <= 0.0 {
    0
  } else {
    round_int_for_seed(minlen)
  }
}

///|
/// Graphviz parity: rank-adjacent seed constraints are emitted in rank/group
/// order before edge-chain segments are added.
pub(all) struct RankConstraintSeed {
  rank_adj_constraints : Map[String, ConstraintEdge]
  rank_adj_order : Array[String]
  order_in_rank : Map[String, Int]
}

///|
/// Graphviz parity: rank-adjacent constraints use rank_nodesep and node widths
/// exactly once per adjacent pair in each rank group.
pub fn build_rank_constraint_seed(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @node_primitives.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> RankConstraintSeed {
  let rank_adj_constraints : Map[String, ConstraintEdge] = Map::new()
  let rank_adj_order : Array[String] = []
  let order_in_rank : Map[String, Int] = Map::new()
  for rank in rank_keys {
    let names = groups.get(rank).unwrap_or_default()
    for i in 0..<names.length() {
      order_in_rank[names[i]] = i
    }
    let rank_nodesep =
      rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    let mut i = 0
    while i + 1 < names.length() {
      let tail = names[i]
      let head = names[i + 1]
      let minlen = nodesep_minlen_for_seed(tail, head, sizes, rank_nodesep)
      let key = "\{tail}|\{head}"
      rank_adj_constraints[key] = {
        tail,
        head,
        minlen,
        weight: 0,
        tail_port: None,
        head_port: None,
      }
      rank_adj_order.push(key)
      i = i + 1
    }
  }
  { rank_adj_constraints, rank_adj_order, order_in_rank }
}

///|
/// Graphviz parity: edge iteration follows ND_out tail order first and then
/// falls back to unseen edge indices in input sequence.
pub fn for_each_edge_index_in_tail_order(
  edges : Array[@cgraph.Edge],
  edge_out_order : Map[String, Array[Int]],
  nlist_order : Array[String],
  visit : (Int) -> Unit,
) -> Unit {
  let seen_edges : Map[Int, Bool] = Map::new()
  for tail_name in nlist_order {
    let indices = edge_out_order.get(tail_name).unwrap_or_default()
    for edge_idx in indices {
      if edge_idx < 0 || edge_idx >= edges.length() {
        continue
      }
      seen_edges[edge_idx] = true
      visit(edge_idx)
    }
  }
  if seen_edges.length() < edges.length() {
    for edge_idx in 0..<edges.length() {
      if seen_edges.get(edge_idx) is None {
        visit(edge_idx)
      }
    }
  }
}
