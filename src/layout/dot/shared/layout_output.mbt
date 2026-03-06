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
