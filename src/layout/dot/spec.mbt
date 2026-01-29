///|
/// Rank direction for dot layout.
pub type RankDir = @dot_shared.RankDir

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
/// Options for dot layout.
pub(all) struct DotLayoutOptions {
  rankdir : RankDir?
  nodesep : Double?
  ranksep : Double?
  splines : SplinesMode?
} derive(Show, Eq)

///|
#declaration_only
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  ...
}

///|
/// Layout errors from the dot engine.
pub(all) suberror DotLayoutError {
  UnsupportedFeature(message~ : String)
  InvalidGraph(message~ : String)
} derive(Show, Eq)

///|
/// Node layout output.
/// pos is in points; width/height are in inches.
pub(all) struct DotLayoutNode {
  node : @cgraph.Node
  pos : @geom.Point
  width_in : Double
  height_in : Double
  label_pos : @geom.Point?
}

///|
/// Edge layout output.
/// Splines use points in points; label positions are optional.
pub(all) struct DotLayoutEdge {
  edge : @cgraph.Edge
  splines : Array[@geom.Spline]
  label_pos : @geom.Point?
  head_label_pos : @geom.Point?
  tail_label_pos : @geom.Point?
}

///|
/// Graph layout output.
/// bbox encloses all nodes, edges, and labels in points.
pub(all) struct DotLayoutGraph {
  graph : @cgraph.Graph
  bbox : @geom.Rect
  label_pos : @geom.Point?
  nodes : Array[DotLayoutNode]
  edges : Array[DotLayoutEdge]
  subgraphs : Array[DotLayoutGraph]
}

///|
/// Run dot layout and return typed geometry output.
/// Invariants:
/// - bbox is normalized and encloses all node boxes and edge splines.
/// - node pos is in points and lies within bbox.
/// - edge splines have 3n+1 control points.
#declaration_only
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  ...
}

///|
/// Build a layout from existing node positions (neato -n style).
/// scale converts pos coordinates from points-per-inch into points.
/// no_op_level > 1 reuses edge pos attributes when present.
#declaration_only
pub fn layout_neato_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  ...
}

///|
/// Build a layout from existing node positions (dot -n style).
/// scale converts pos coordinates from points-per-inch into points.
/// no_op_level > 1 reuses edge pos attributes when present.
#declaration_only
pub fn layout_dot_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  ...
}

///|
/// Run neato layout and return typed geometry output.
/// scale controls the output coordinate scale (points per inch).
#declaration_only
pub fn layout_neato(
  graph : @cgraph.Graph,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  ...
}

///|
/// Attach layout attributes (bb, pos, lp, edge pos, etc.) to the graph.
#declaration_only
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  ...
}
