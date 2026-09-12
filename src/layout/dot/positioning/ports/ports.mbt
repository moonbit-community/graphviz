// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Positioning-owned port geometry and self-edge spacing logic shared across
/// ordering, positioning, and routing stage boundaries.
type RankDir = @rankdir.RankDir

///|
type RecordOrientation = @layout_prep.RecordOrientation

///|
type NodeSize = @node_primitives.NodeSize

///|
type RecordPort = @record_geometry.RecordPort

///|
/// Graphviz parity: port offset sampling aligned to dot position/order logic,
/// including record/html port handling and rankdir-aware shape transforms.
/// Do not change behavior without updating fixtures/tests.
pub fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  build_port_offsets_with_callbacks(
    nodes,
    output_sizes,
    (node, rankdir) => {
      let record_orientation = @layout_prep.record_layout_orientation(rankdir)
      @node_geometry.node_size(node, record_orientation)
    },
    (node, origin, base_size, rankdir) => {
      let record_orientation = @layout_prep.record_layout_orientation(rankdir)
      @label_layout.raw_label_ports_for_node(
        node, origin, base_size, record_orientation,
      )
    },
    @port_geometry.layout_port_offset,
    @node_primitives.swap_node_size,
  )
}

///|
fn compass_port_point_for_layout(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  resolve_compass_port_point(
    node_name,
    node,
    compass,
    sizes,
    rankdir,
    @node_geometry.compass_uses_shape_clipping,
    (shape_node, size, shape_compass, shape_rankdir) => {
      @edge_spline.compass_port_point_on_shape(
        shape_node,
        @edge_spline.point(0.0, 0.0),
        size,
        shape_compass,
        shape_rankdir,
      )
    },
    @port_geometry.layout_port_offset,
  )
}

///|
/// Resolve the initial port coordinates used by dot's ports_eq, before
/// dynamic ports are moved to a node side during routing. None is Center's
/// undefined port; a defined port at (0, 0) is a distinct state.
fn initial_port_point(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point? {
  guard port is Some(port) else { None }
  if port.name is Some(name) {
    if offsets.get(node.name()) is Some(node_offsets) {
      if node_offsets.get(name) is Some(info) {
        guard port.compass is Some(compass) else { return Some(info.center) }
        let output_size = if rankdir == @rankdir.RankDir::LR ||
          rankdir == @rankdir.RankDir::RL {
          @node_primitives.swap_node_size(info.size)
        } else {
          info.size
        }
        let displacement = record_port_point(
          { ..info, center: { x: 0.0, y: 0.0, }, size: output_size, },
          Some(compass),
        )
        let offset = @port_geometry.layout_port_offset(displacement, rankdir)
        return Some({
          x: info.center.x + offset.x,
          y: info.center.y + offset.y,
        })
      }
    }
  }
  let is_record = @record_geometry.is_record_shape(node)
  if port.compass is Some(compass) {
    if compass == @cgraph.Compass::C && !is_record {
      return None
    }
    return Some(
      compass_port_point_for_layout(
        node.name(),
        Some(node),
        compass,
        sizes,
        rankdir,
      ),
    )
  }
  if is_record && port.name is Some(_) {
    Some({ x: 0.0, y: 0.0, })
  } else {
    None
  }
}

///|
pub fn build_initial_port_sampler(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> (@cgraph.Node, @cgraph.Port?) -> @geom.Point? {
  let offsets = port_offsets_for_nodes(nodes, output_sizes)
  let rankdir = if nodes.length() > 0 {
    @rankdir.graph_rankdir(nodes[0].graph())
  } else {
    @rankdir.RankDir::TB
  }
  let sizes : Map[String, NodeSize] = Map([])
  for node in nodes {
    let size = output_sizes
      .get(node.name())
      .unwrap_or_else(() => {
        @node_geometry.node_size(
          node,
          @layout_prep.record_layout_orientation(rankdir),
        )
      })
    sizes[node.name()] = if rankdir == @rankdir.RankDir::LR ||
      rankdir == @rankdir.RankDir::RL {
      @node_primitives.swap_node_size(size)
    } else {
      size
    }
  }
  (node, port) => initial_port_point(node, port, offsets, sizes, rankdir)
}

///|
/// Compare a node's initial ports by definedness and coordinates (portcmp).
pub fn build_initial_node_port_comparator(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> (@cgraph.Node, @cgraph.Port?, @cgraph.Port?) -> Bool {
  let sample = build_initial_port_sampler(nodes, output_sizes)
  (node, first, second) => sample(node, first) == sample(node, second)
}

///|
/// Compare initial edge ports using upstream's asymmetric ports_eq predicate.
/// An undefined first tail ignores tail position. Endpoint ports are not swapped.
pub fn build_initial_edge_port_comparator(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> (@cgraph.Edge, @cgraph.Edge) -> Bool {
  let sample = build_initial_port_sampler(nodes, output_sizes)
  (first, second) => {
    let first_head = sample(first.head(), first.head_port())
    let second_head = sample(second.head(), second.head_port())
    guard first_head == second_head else { false }
    guard sample(first.tail(), first.tail_port()) is Some(first_tail) else {
      true
    }
    let second_tail = sample(second.tail(), second.tail_port()).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
    first_tail == second_tail
  }
}

///|
pub fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  // Named field geometry needs compass displacement in layout coordinates.
  // Compass-only ports retain the shape-specific sampling path below.
  if port is Some({ name: Some(name), .. }) &&
    offsets.get(node_name) is Some(node_offsets) &&
    node_offsets.get(name) is Some(_) &&
    nodes_by_name.get(node_name) is Some(node) {
    return initial_port_point(node, port, offsets, sizes, rankdir).map_or(0.0, point => {
      point.x
    })
  }
  sample_edge_port_offset(node_name, port, offsets, compass => {
    sample_compass_port_offset(
      compass,
      node_name,
      sizes,
      rankdir,
      nodes_by_name.get(node_name),
      compass_port_point_for_layout,
      node => {
        @record_geometry.is_record_shape(node) ||
        @html_label.is_html_label_text(@label_attrs.label_text(node))
      },
      @port_geometry.layout_port_offset,
    )
  })
}

///|
pub fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  sample_edge_port_order(node_name, port, offsets, compass => {
    compass_port_point_for_layout(
      node_name,
      nodes_by_name.get(node_name),
      compass,
      sizes,
      rankdir,
    )
  })
}

///|
/// Graphviz parity: dot edge-port sample bundle keeps the shared port-offset,
/// port-order, and rankdir-aware bridge policy centralized for ordering/xpos
/// preprocessing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_edge_port_sample_bundle(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> @setup.EdgePortSampleBundle {
  build_edge_port_samples_with_callbacks(
    nodes, edges, edge_tail, edge_head, sizes, port_offsets_for_nodes, edge_port_offset,
    edge_port_order,
  )
}

///|
fn build_port_maps_for_nodes(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, RecordPort]] {
  let origin = @geom.Point::{ x: 0.0, y: 0.0, }
  let port_maps : Map[String, Map[String, RecordPort]] = Map([])
  for node in nodes {
    let name = node.name()
    let size = @node_geometry.resolve_node_output_size(
      sizes, node, record_orientation,
    )
    let ports = @label_layout.raw_label_ports_for_node(
      node, origin, size, record_orientation,
    )
    if ports.length() > 0 {
      port_maps[name] = ports
    }
  }
  port_maps
}

///|
fn port_side_mask_for_self_edge(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Int {
  match port {
    None => 0
    Some(value) =>
      match value.compass {
        Some(compass) => @port_geometry.compass_side_mask(compass)
        None =>
          match value.name {
            Some(port_name) =>
              match port_maps.get(node.name()) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(info) => info.sides
                    None => 0
                  }
                None => 0
              }
            None => 0
          }
      }
  }
}

///|
/// Graphviz parity: self-edge right-side spacing aligned to
/// refs/graphviz/lib/dotgen/position.c (self-edge width padding).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_self_edge_right_space(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, NodeSize] {
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  @self_edge.apply_self_edge_right_space({
    edges,
    sizes,
    rankdir,
    self_edge_size_pt: @node_geometry.SELF_EDGE_SIZE_PT,
    self_edge_label_width_for: @edge_label_metrics.self_edge_label_width_pt,
    port_side_mask_for: (node, port) => {
      port_side_mask_for_self_edge(node, port, port_maps)
    },
  })
}
