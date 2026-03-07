///|
/// X-constraint domain: rank-spacing helpers shared by xpos constraint graph
/// assembly and clustered xpos boundary construction.

///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const EDGE_LABEL_NODESEP_PT : Double = 5.0

///|
/// Graphviz parity: ratio=compress detection aligned to
/// refs/graphviz/lib/dotgen/dotinit.c.
fn graph_ratio_is_compress(graph : @cgraph.Graph) -> Bool {
  match graph.get_attr("ratio") {
    Some(value) => value.trim().to_lower() == "compress"
    None => false
  }
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c
/// and dotgen/position.c (compress_graph input width).
/// Graphviz parity: compress_graph width clamp aligned to
/// refs/graphviz/lib/dotgen/position.c (MIN(size, USHRT_MAX)).
pub fn compress_width_minlen_pt(
  graph : @cgraph.Graph,
  rankdir : @shared.RankDir,
) -> Int? {
  if !graph_ratio_is_compress(graph) {
    return None
  }
  let size = match @numeric.parse_graph_size_pt_attr(graph) {
    Some(value) => value
    None => return None
  }
  let width_pt = match rankdir {
    @shared.RankDir::LR | @shared.RankDir::RL => size.height_pt
    _ => size.width_pt
  }
  if width_pt <= 1.0 {
    return None
  }
  let clamped = if width_pt > 65535.0 { 65535.0 } else { width_pt }
  Some(@numeric.round_int(clamped))
}

///|
fn size_left_pt(name : String, sizes : Map[String, @node_primitives.NodeSize]) -> Double {
  match sizes.get(name) {
    Some(size) => size.left_pt
    None => 1.0
  }
}

///|
fn size_right_pt(name : String, sizes : Map[String, @node_primitives.NodeSize]) -> Double {
  match sizes.get(name) {
    Some(size) => size.right_pt
    None => 1.0
  }
}

///|
pub fn rank_nodesep_pt(
  rank : Int,
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Double {
  if has_edge_labels && rank % 2 != 0 {
    EDGE_LABEL_NODESEP_PT
  } else {
    nodesep_pt
  }
}

///|
pub fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @node_primitives.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = groups.get(rank).unwrap_or_default()
    if names.length() == 0 {
      continue
    }
    let first = names[0]
    positions[first] = 0.0
    let mut current = 0
    let mut prev = first
    let mut i = 1
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    while i < names.length() {
      let name = names[i]
      let tail_right = size_right_pt(prev, sizes)
      let head_left = size_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = @numeric.trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}
