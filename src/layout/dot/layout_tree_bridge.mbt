///|
/// Bridge between the public root layout type and the internal shared layout
/// tree used by tree-heavy subpackages.

type LayoutTree = @dot_shared.LayoutTree

///|
fn dot_layout_graph_from_layout_tree(layout : LayoutTree) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(dot_layout_graph_from_layout_tree(subgraph))
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

