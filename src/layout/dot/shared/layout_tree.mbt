///|
/// Internal recursive layout tree used by dot subpackages so tree-heavy
/// algorithms do not need to depend directly on the root public layout type.

pub(all) struct LayoutTree {
  graph : @cgraph.Graph
  bbox : @geom.Rect
  label_pos : @geom.Point?
  nodes : Array[DotLayoutNode]
  edges : Array[DotLayoutEdge]
  subgraphs : Array[LayoutTree]
}
