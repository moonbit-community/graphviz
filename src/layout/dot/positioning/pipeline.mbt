///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from precomputed stage flags.
pub struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
}

///|
/// Graphviz parity: position-mode source bundle keeps vnode caps and rankdir
/// together so Stage D call-sites avoid positional argument drift.
pub(all) struct PositionModeFlagSources {
  has_edge_labels : Bool
  has_port_edges : Bool
  vnode_count : Int
  max_xpos_vnodes : Int
  max_xpos_reorder_vnodes : Int
  rankdir : @rankdir.RankDir
}

///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
pub fn build_position_mode_flags(
  sources : PositionModeFlagSources,
) -> PositionModeFlags {
  let use_vnodes_for_xpos =
    sources.has_edge_labels || sources.has_port_edges ||
    sources.vnode_count <= sources.max_xpos_vnodes
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || sources.vnode_count <= sources.max_xpos_reorder_vnodes
  let graphviz_flip =
    sources.rankdir == @rankdir.RankDir::LR || sources.rankdir == @rankdir.RankDir::RL
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: position stage result keeps x/y coordinates, vnode
/// positions, and cluster bbox metadata grouped for downstream stages.
pub(all) struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, @clustering.ClusterBboxHeightPair]
}

