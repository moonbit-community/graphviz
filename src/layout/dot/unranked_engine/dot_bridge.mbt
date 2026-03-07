///|
/// Dot-package bridge for unranked engine output projection: convert solved or
/// fixed positions into shared node/edge layout records without root tree
/// finalization.

type DotLayoutNode = @shared.DotLayoutNode
type DotLayoutEdge = @shared.DotLayoutEdge

///|
pub(all) struct EngineNodeProjection {
  positions : Map[String, @geom.Point]
  nodes_out : Array[DotLayoutNode]
}

///|
pub(all) struct EngineNodeProjectionWithSizes {
  projection : EngineNodeProjection
  sizes : Map[String, NodeSize]
}

///|
pub fn build_projected_nodes_from_positions(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  node_size_for : (@cgraph.Node) -> NodeSize,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let pos = match positions.get(node.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = node_size_for(node)
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  nodes_out
}

///|
pub fn project_scaled_nodes_with_sizes(
  nodes : Array[@cgraph.Node],
  positions : Array[@geom.Point],
  scale_factor : Double,
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> EngineNodeProjectionWithSizes {
  let positions_map : Map[String, @geom.Point] = Map::new()
  for i in 0..<nodes.length() {
    let node = nodes[i]
    positions_map[node.name()] = scale_point(positions[i], scale_factor)
  }
  let nodes_out =
    build_projected_nodes_from_positions(
      nodes,
      positions_map,
      node => node_size_with_fallback(sizes, node, record_orientation),
    )
  {
    projection: { positions: positions_map, nodes_out },
    sizes,
  }
}

///|
pub fn build_edges_from_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  node_size_for : (@cgraph.Node) -> NodeSize,
  edge_splines_for :
    (@cgraph.Edge, @geom.Point, @geom.Point, NodeSize, NodeSize) -> Array[@geom.Spline],
) -> Array[DotLayoutEdge] {
  let edges_out : Array[DotLayoutEdge] = []
  for edge in graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_pos = match positions.get(tail.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = node_size_for(tail)
    let head_size = node_size_for(head)
    edges_out.push({
      edge,
      splines: edge_splines_for(edge, tail_pos, head_pos, tail_size, head_size),
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
      xlabel_pos: None,
    })
  }
  edges_out
}
