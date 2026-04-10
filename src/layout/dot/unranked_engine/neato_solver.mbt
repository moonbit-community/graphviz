// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Neato force-directed solve owner for unranked layout: pinned-pos parsing,
/// node sizing/indexing, edge spring construction, cooling/relax, and neato
/// layout-tree assembly.

///|
/// Graphviz parity: unranked neato output assembly keeps force-directed solve,
/// scaling, edge projection, and final layout-tree postprocess in one package
/// entry so the root API boundary stays thin.
fn build_neato_layout_tree(
  graph : @cgraph.Graph,
  scale : Double,
  nodesep_pt : Double,
) -> LayoutTree {
  let geometry = build_engine_geometry_context(graph, scale)
  let nodes = graph.nodes()
  let node_count = nodes.length()
  let sizing = build_neato_node_sizing(nodes, geometry.record_orientation)
  let base_spacing = sizing.max_half * 2.0 + nodesep_pt
  let spacing = if base_spacing <= 1.0 { 1.0 } else { base_spacing }
  let node_state = build_neato_initial_node_state(nodes, spacing)
  let positions = node_state.positions
  let pinned = node_state.pinned
  let edges = build_neato_edges(graph, sizing.indices, sizing.radii, nodesep_pt)
  if node_count > 1 {
    relax_positions(
      positions,
      pinned,
      sizing.radii,
      edges,
      spacing,
      nodesep_pt,
      100,
    )
  }
  let node_data = project_scaled_nodes_with_sizes(
    nodes,
    positions,
    geometry.scale_factor,
    sizing.sizes,
    geometry.record_orientation,
  )
  let node_size_for = (node : @cgraph.Node) => {
    node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  }
  let edges_out = build_edges_from_positions(
    graph,
    node_data.projection.positions,
    node_size_for,
    straight_line_edge_splines,
  )
  finalize_unranked_layout_tree(
    graph,
    geometry.rankdir,
    node_data.projection.nodes_out,
    edges_out,
  )
}

///|
fn is_pin_value(value : String) -> Bool {
  match value.to_lower() {
    "true" | "yes" | "1" => true
    _ => false
  }
}

///|
fn pos_is_pinned(value : String) -> Bool {
  if value == "" {
    return false
  }
  let last = value[value.length() - 1]
  last == '!'
}

///|
priv struct NodePosHint {
  pos : @geom.Point?
  is_pinned : Bool
}

///|
fn node_pos_hint(node : @cgraph.Node) -> NodePosHint {
  let pin_attr = match node.get_attr("pin") {
    Some(value) => is_pin_value(value)
    None => false
  }
  match node.get_attr("pos") {
    Some(value) =>
      match parse_point_attr(value) {
        Some(pos) => {
          let pinned = pin_attr || pos_is_pinned(value)
          { pos: Some(pos), is_pinned: pinned }
        }
        None => { pos: None, is_pinned: false }
      }
    None => { pos: None, is_pinned: false }
  }
}

///|
pub struct NeatoEdge {
  tail : Int
  head : Int
  length_pt : Double
  weight : Double
}

///|
pub struct NeatoNodeSizing {
  sizes : Map[String, NodeSize]
  indices : Map[String, Int]
  radii : Array[Double]
  max_half : Double
}

///|
pub fn build_neato_node_sizing(
  nodes : Array[@cgraph.Node],
  record_orientation : RecordOrientation,
) -> NeatoNodeSizing {
  let sizes : Map[String, NodeSize] = Map::new()
  let indices : Map[String, Int] = Map::new()
  let radii : Array[Double] = []
  let mut max_half = 0.0
  for i in 0..<nodes.length() {
    let node = nodes[i]
    let size = @node_geometry.node_size(node, record_orientation)
    sizes[node.name()] = size
    indices[node.name()] = i
    let half = if size.width_pt > size.height_pt {
      size.width_pt / 2.0
    } else {
      size.height_pt / 2.0
    }
    radii.push(half)
    if half > max_half {
      max_half = half
    }
  }
  { sizes, indices, radii, max_half }
}

///|
pub struct NeatoInitialNodeState {
  positions : Array[@geom.Point]
  pinned : Array[Bool]
}

///|
pub fn build_neato_initial_node_state(
  nodes : Array[@cgraph.Node],
  spacing : Double,
) -> NeatoInitialNodeState {
  let node_count = nodes.length()
  let mut radius = if node_count > 1 {
    spacing * node_count.to_double() / (2.0 * @math.PI)
  } else {
    0.0
  }
  if node_count > 1 && radius < spacing {
    radius = spacing
  }
  let positions : Array[@geom.Point] = []
  let pinned : Array[Bool] = []
  for i in 0..<node_count {
    let node = nodes[i]
    let angle = if node_count > 0 {
      2.0 * @math.PI * i.to_double() / node_count.to_double()
    } else {
      0.0
    }
    let base_pos : @geom.Point = {
      x: radius * @math.cos(angle),
      y: radius * @math.sin(angle),
    }
    let hint_data = node_pos_hint(node)
    let pos = match hint_data.pos {
      Some(value) => value
      None => base_pos
    }
    positions.push(pos)
    pinned.push(hint_data.is_pinned)
  }
  { positions, pinned }
}

///|
pub fn build_neato_edges(
  graph : @cgraph.Graph,
  indices : Map[String, Int],
  radii : Array[Double],
  nodesep_pt : Double,
) -> Array[NeatoEdge] {
  let edges : Array[NeatoEdge] = []
  for edge in graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_index = match indices.get(tail.name()) {
      Some(value) => value
      None => continue
    }
    let head_index = match indices.get(head.name()) {
      Some(value) => value
      None => continue
    }
    if tail_index == head_index {
      continue
    }
    let len_in = match edge.get_attr("len") {
      Some(value) => @numeric.parse_double_or(value, 1.0)
      None => 1.0
    }
    let length_in = if len_in <= 0.0 { 1.0 } else { len_in }
    let length_pt = length_in * 72.0
    let raw_weight = match edge.get_attr("weight") {
      Some(value) => @numeric.parse_double_or(value, 1.0)
      None => 1.0
    }
    let weight = if raw_weight <= 0.0 { 1.0 } else { raw_weight }
    let min_len = radii[tail_index] + radii[head_index] + nodesep_pt
    let desired = if length_pt > min_len { length_pt } else { min_len }
    edges.push({
      tail: tail_index,
      head: head_index,
      length_pt: desired,
      weight,
    })
  }
  edges
}

///|
fn zero_double_array(length : Int) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<length {
    values.push(0.0)
  }
  values
}

///|
fn accumulate_repulsive_forces(
  positions : Array[@geom.Point],
  radii : Array[Double],
  spacing : Double,
  nodesep_pt : Double,
  eps : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
  let node_count = positions.length()
  for i in 0..<node_count {
    let pos_i = positions[i]
    for j in (i + 1)..<node_count {
      let pos_j = positions[j]
      let dx = pos_i.x - pos_j.x
      let dy = pos_i.y - pos_j.y
      let dist = Double::sqrt(dx * dx + dy * dy) + eps
      let min_dist = radii[i] + radii[j] + nodesep_pt
      let mut rep = spacing * spacing / dist
      if dist < min_dist {
        let overlap = min_dist - dist
        rep = rep + overlap * spacing / min_dist
      }
      let fx = dx / dist * rep
      let fy = dy / dist * rep
      disp_x[i] = disp_x[i] + fx
      disp_y[i] = disp_y[i] + fy
      disp_x[j] = disp_x[j] - fx
      disp_y[j] = disp_y[j] - fy
    }
  }
}

///|
fn accumulate_spring_forces(
  positions : Array[@geom.Point],
  edges : Array[NeatoEdge],
  eps : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
  for edge in edges {
    let u = edge.tail
    let v = edge.head
    let pos_u = positions[u]
    let pos_v = positions[v]
    let dx = pos_u.x - pos_v.x
    let dy = pos_u.y - pos_v.y
    let dist = Double::sqrt(dx * dx + dy * dy) + eps
    let force = (dist - edge.length_pt) * edge.weight
    let fx = dx / dist * force
    let fy = dy / dist * force
    disp_x[u] = disp_x[u] - fx
    disp_y[u] = disp_y[u] - fy
    disp_x[v] = disp_x[v] + fx
    disp_y[v] = disp_y[v] + fy
  }
}

///|
fn apply_displacements(
  positions : Array[@geom.Point],
  pinned : Array[Bool],
  temperature : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
  for i in 0..<positions.length() {
    if pinned[i] {
      continue
    }
    let dx = disp_x[i]
    let dy = disp_y[i]
    let disp_len = Double::sqrt(dx * dx + dy * dy)
    if disp_len > 0.0 {
      let step = if disp_len < temperature { disp_len } else { temperature }
      positions[i] = {
        x: positions[i].x + dx / disp_len * step,
        y: positions[i].y + dy / disp_len * step,
      }
    }
  }
}

///|
fn recenter_positions(positions : Array[@geom.Point]) -> Unit {
  if positions.length() == 0 {
    return ()
  }
  let mut cx = 0.0
  let mut cy = 0.0
  for pos in positions {
    cx = cx + pos.x
    cy = cy + pos.y
  }
  let inv = 1.0 / positions.length().to_double()
  cx = cx * inv
  cy = cy * inv
  for i in 0..<positions.length() {
    positions[i] = { x: positions[i].x - cx, y: positions[i].y - cy }
  }
}

///|
pub fn relax_positions(
  positions : Array[@geom.Point],
  pinned : Array[Bool],
  radii : Array[Double],
  edges : Array[NeatoEdge],
  spacing : Double,
  nodesep_pt : Double,
  iterations : Int,
) -> Unit {
  let node_count = positions.length()
  if node_count <= 1 {
    return ()
  }
  let mut pinned_count = 0
  for value in pinned {
    if value {
      pinned_count = pinned_count + 1
    }
  }
  if pinned_count == node_count {
    return ()
  }
  let mut temperature = spacing * Double::sqrt(node_count.to_double())
  let eps = 0.01
  let mut iter = 0
  while iter < iterations && temperature > 0.01 {
    let disp_x = zero_double_array(node_count)
    let disp_y = zero_double_array(node_count)
    accumulate_repulsive_forces(
      positions, radii, spacing, nodesep_pt, eps, disp_x, disp_y,
    )
    accumulate_spring_forces(positions, edges, eps, disp_x, disp_y)
    apply_displacements(positions, pinned, temperature, disp_x, disp_y)
    if pinned_count == 0 {
      recenter_positions(positions)
    }
    temperature = temperature * 0.9
    iter = iter + 1
  }
}
