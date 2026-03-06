///|
pub struct EdgeLabelRankInfo {
  label_rank : Int
  span : Int
}

///|
/// Graphviz parity: edge label rank selection follows dotsplines midpoint-rank
/// logic and only applies to long edges with non-empty mid labels.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  mid_label_width_pt : Double,
) -> EdgeLabelRankInfo? {
  if mid_label_width_pt <= 0.0 {
    return None
  }
  let rank_span = match @dot_shared.edge_rank_span(edge, ranks) {
    Some(value) => value
    None => return None
  }
  let min_rank = rank_span.min_rank
  let max_rank = rank_span.max_rank
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some({ label_rank, span })
}

///|
pub fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  mid_label_width_pt : Double,
) -> Double? {
  match edge_label_rank_info(edge, ranks, mid_label_width_pt) {
    Some(info) => rank_y.get(info.label_rank)
    None => None
  }
}

///|
/// Graphviz parity: rank-x anchor for edge labels reuses vnode rank mapping
/// and edge vnode chain lookup aligned to dotsplines vnode label placement.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match vnode_info.edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_info.vnode_ranks.get(name) {
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
