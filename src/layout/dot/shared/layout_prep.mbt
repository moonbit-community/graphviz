type RankDir = @rankdir.RankDir

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
  output_sizes : Map[String, @node_primitives.NodeSize]
  order_sizes : Map[String, @node_primitives.NodeSize]
  sizes : Map[String, @node_primitives.NodeSize]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

