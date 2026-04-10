// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Fixed-position noop layout owner: edge pos parsing/reuse, required node pos
/// collection, and noop layout-tree assembly.

///|
priv enum EdgeTokenTag {
  Start
  End
}

///|
priv struct EdgeTokenParse {
  tag : EdgeTokenTag?
  point : @geom.Point?
}

///|
fn parse_edge_token(token : String) -> EdgeTokenParse {
  if token == "" {
    return { tag: None, point: None }
  }
  if token.has_prefix("s,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return { tag: Some(EdgeTokenTag::Start), point: parse_point_attr(rest) }
  }
  if token.has_prefix("e,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return { tag: Some(EdgeTokenTag::End), point: parse_point_attr(rest) }
  }
  { tag: None, point: parse_point_attr(token) }
}

///|
fn normalize_spline_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() >= 4 && (points.length() - 1) % 3 == 0 {
    points
  } else if points.length() >= 2 {
    line_control_points(points[0], points[points.length() - 1])
  } else {
    []
  }
}

///|
fn parse_edge_pos_segment(
  segment : String,
  scale_factor : Double,
) -> @geom.Spline? {
  let mut start : @geom.Point? = None
  let mut end : @geom.Point? = None
  let points : Array[@geom.Point] = []
  for token in segment.split(" ") {
    let parsed = parse_edge_token(token.to_string())
    match parsed.point {
      Some(value) => {
        let scaled = scale_point(value, scale_factor)
        match parsed.tag {
          Some(EdgeTokenTag::Start) => start = Some(scaled)
          Some(EdgeTokenTag::End) => end = Some(scaled)
          None => points.push(scaled)
        }
      }
      None => ()
    }
  }
  let normalized = normalize_spline_points(points)
  if normalized.length() > 0 {
    Some({ start, end, points: normalized })
  } else {
    None
  }
}

///|
pub fn parse_edge_pos(
  value : String,
  scale_factor : Double,
) -> Array[@geom.Spline] {
  let splines : Array[@geom.Spline] = []
  for segment in value.split(";") {
    match parse_edge_pos_segment(segment.to_string(), scale_factor) {
      Some(spline) => splines.push(spline)
      None => ()
    }
  }
  splines
}

///|
pub fn noop_edge_splines(
  edge : @cgraph.Edge,
  use_edge_pos : Bool,
  scale_factor : Double,
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : @node_primitives.NodeSize,
  head_size : @node_primitives.NodeSize,
) -> Array[@geom.Spline] {
  if use_edge_pos {
    match edge.get_attr("pos") {
      Some(value) => {
        let parsed = parse_edge_pos(value, scale_factor)
        if parsed.length() > 0 {
          parsed
        } else {
          straight_line_edge_splines(
            edge, tail_pos, head_pos, tail_size, head_size,
          )
        }
      }
      None =>
        straight_line_edge_splines(
          edge, tail_pos, head_pos, tail_size, head_size,
        )
    }
  } else {
    straight_line_edge_splines(edge, tail_pos, head_pos, tail_size, head_size)
  }
}

///|
fn required_scaled_noop_node_pos(
  node : @cgraph.Node,
  scale_factor : Double,
) -> Result[@geom.Point, String] {
  let pos_value = match node.get_attr("pos") {
    Some(value) => value
    None => return Err("neato -n requires pos for node \{node.name()}")
  }
  let parsed = match parse_point_attr(pos_value) {
    Some(value) => value
    None => return Err("invalid pos for node \{node.name()}")
  }
  Ok(scale_point(parsed, scale_factor))
}

///|
fn collect_noop_nodes_with_sizes(
  graph : @cgraph.Graph,
  scale_factor : Double,
  record_orientation : @layout_prep.RecordOrientation,
) -> Result[EngineNodeProjectionWithSizes, String] {
  let nodes = graph.nodes()
  let positions : Map[String, @geom.Point] = Map::new()
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  for node in nodes {
    let pos = match required_scaled_noop_node_pos(node, scale_factor) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    positions[node.name()] = pos
    sizes[node.name()] = @node_geometry.node_size(node, record_orientation)
  }
  let nodes_out = build_projected_nodes_from_positions(nodes, positions, node => {
    node_size_with_fallback(sizes, node, record_orientation)
  })
  Ok({ projection: { positions, nodes_out }, sizes })
}

///|
/// Graphviz parity: noop output assembly keeps fixed-position node parsing,
/// optional edge-pos reuse, and final layout-tree writeback together inside the
/// unranked_engine package so the root API boundary stays thin.
fn build_noop_layout_tree(
  graph : @cgraph.Graph,
  no_op_level : Int,
  scale : Double,
) -> Result[@layout_tree.LayoutTree, String] {
  let geometry = build_engine_geometry_context(graph, scale)
  let node_data = match
    collect_noop_nodes_with_sizes(
      graph,
      geometry.scale_factor,
      geometry.record_orientation,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let use_edge_pos = no_op_level > 1
  let node_size_for = (node : @cgraph.Node) => {
    node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  }
  let edges_out = build_edges_from_positions(
    graph,
    node_data.projection.positions,
    node_size_for,
    (edge, tail_pos, head_pos, tail_size, head_size) => {
      noop_edge_splines(
        edge,
        use_edge_pos,
        geometry.scale_factor,
        tail_pos,
        head_pos,
        tail_size,
        head_size,
      )
    },
  )
  Ok(
    finalize_unranked_layout_tree(
      graph,
      geometry.rankdir,
      node_data.projection.nodes_out,
      edges_out,
    ),
  )
}
