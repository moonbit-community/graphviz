///|
fn xlabel_make_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  nodes? : Array[DotLayoutNode] = [],
  edges? : Array[DotLayoutEdge] = [],
  subgraphs? : Array[@layout_tree.LayoutTree] = [],
) -> @layout_tree.LayoutTree {
  { graph, bbox, label_pos: None, nodes, edges, subgraphs }
}

///|
fn make_set_xlabel(
  target : XLabelTarget,
  width : Double,
  height : Double,
  pos : @geom.Point,
) -> XLabel {
  { target, width, height, pos, set: true }
}
