///|
/// Node layout output.
/// pos is in points; width/height are in inches.
pub(all) struct DotLayoutNode {
  node : @cgraph.Node
  pos : @geom.Point
  width_in : Double
  height_in : Double
  label_pos : @geom.Point?
  xlabel_pos : @geom.Point?
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
  xlabel_pos : @geom.Point?
}
