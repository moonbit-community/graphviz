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
