///|
/// Bridge between the public root layout type and the internal shared layout
/// tree used by tree-heavy subpackages.

type LayoutTree = @dot_shared.LayoutTree

///|
fn layout_tree_from_dot_layout_graph(layout : DotLayoutGraph) -> LayoutTree {
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(layout_tree_from_dot_layout_graph(subgraph))
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

///|
fn dot_layout_graphs_from_layout_trees(
  layouts : Array[LayoutTree],
) -> Array[DotLayoutGraph] {
  let result : Array[DotLayoutGraph] = []
  for layout in layouts {
    result.push(dot_layout_graph_from_layout_tree(layout))
  }
  result
}
