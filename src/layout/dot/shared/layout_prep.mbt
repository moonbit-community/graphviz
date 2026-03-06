///|
/// Edge routing mode for dot layouts.
pub(all) enum SplinesMode {
  Spline
  Polyline
  Ortho
  Curved
  None
} derive(Show, Eq)

///|
/// Record/html label layout orientation used by node-size and port geometry
/// calculations.
pub(all) enum RecordOrientation {
  Horizontal
  Vertical
}

///|
/// Graphviz parity: rankdir LR/RL flips record layout orientation for record
/// and html label geometry.
/// Do not change behavior without updating fixtures/tests.
pub fn record_layout_orientation(rankdir : RankDir) -> RecordOrientation {
  match rankdir {
    RankDir::LR | RankDir::RL => RecordOrientation::Vertical
    _ => RecordOrientation::Horizontal
  }
}

///|
/// Graphviz parity: prepared layout inputs keep canonicalized graph attributes,
/// node/edge snapshots, and derived geometry maps grouped for downstream
/// stages.
pub(all) struct LayoutPrep {
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_dotted_edges : Bool
  has_port_edges : Bool
  has_edge_labels : Bool
  node_order : Map[String, Int]
  record_orientation : RecordOrientation
  output_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  sizes : Map[String, NodeSize]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}


///|
/// Graphviz parity: edge flag scan checks dotted style and explicit ports in
/// edge creation order before downstream ordering and positioning setup.
pub(all) struct EdgeFlags {
  has_dotted_edges : Bool
  has_port_edges : Bool
}

///|
/// Graphviz parity: edge flag scan checks dotted style and explicit ports in
/// edge creation order before downstream ordering setup.
/// Do not change behavior without updating fixtures/tests.
pub fn scan_edge_flags(edges : Array[@cgraph.Edge]) -> EdgeFlags {
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  { has_dotted_edges, has_port_edges }
}

///|
/// Graphviz parity: output-size lookup prefers precomputed output sizes and
/// falls back to node geometry calculation when a node is not present.
pub fn resolve_node_output_size(
  output_sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
  node_size_for_missing : (@cgraph.Node, RecordOrientation) -> NodeSize,
) -> NodeSize {
  let name = node.name()
  match output_sizes.get(name) {
    Some(value) => value
    None => node_size_for_missing(node, record_orientation)
  }
}
