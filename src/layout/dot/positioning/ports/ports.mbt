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
pub fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
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
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  let port_maps : Map[String, Map[String, RecordPort]] = Map::new()
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
