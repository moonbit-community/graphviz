///|
/// Shared port-geometry bridge logic used across ordering, positioning, and
/// routing stage boundaries.

type RankDir = @shared.RankDir
type RecordOrientation = @shared.RecordOrientation
type NodeSize = @shared.NodeSize
type RecordPort = @shared.RecordPort

///|
/// Graphviz parity: port offset sampling aligned to dot position/order logic,
/// including record/html port handling and rankdir-aware shape transforms.
/// Do not change behavior without updating fixtures/tests.
pub fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  @positioning.build_port_offsets_for_nodes(
    nodes,
    output_sizes,
    (node, rankdir) => {
      let record_orientation = @shared.record_layout_orientation(rankdir)
      @node_geometry.node_size(node, record_orientation)
    },
    (node, origin, base_size, rankdir) => {
      let record_orientation = @shared.record_layout_orientation(rankdir)
      @label_layout.raw_label_ports_for_node(node, origin, base_size, record_orientation)
    },
    @label_layout.layout_port_offset,
    @shared.swap_node_size,
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
  @positioning.compass_port_point(
    node_name,
    node,
    compass,
    sizes,
    rankdir,
    @node_geometry.compass_uses_shape_clipping,
    (shape_node, size, shape_compass, shape_rankdir) =>
      @edge_spline.compass_port_point_on_shape(
        shape_node,
        @edge_spline.point(0.0, 0.0),
        size,
        shape_compass,
        shape_rankdir,
      ),
    @label_layout.layout_port_offset,
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
  @positioning.edge_port_offset(
    node_name,
    port,
    offsets,
    compass =>
      @positioning.compass_port_offset(
        compass,
        node_name,
        sizes,
        rankdir,
        nodes_by_name.get(node_name),
        compass_port_point_for_layout,
        node =>
          @shared.is_record_shape(node) ||
          @html_label.is_html_label_text(@label_layout.label_text(node)),
        @label_layout.layout_port_offset,
      ),
  )
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
  @positioning.edge_port_order(
    node_name,
    port,
    offsets,
    compass =>
      compass_port_point_for_layout(
        node_name,
        nodes_by_name.get(node_name),
        compass,
        sizes,
        rankdir,
      ),
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
    let size = @shared.resolve_node_output_size(sizes, node, record_orientation, @node_geometry.node_size)
    let ports =
      @label_layout.raw_label_ports_for_node(
        node,
        origin,
        size,
        record_orientation,
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
        Some(compass) => @label_layout.compass_side_mask(compass)
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
  @self_edge.apply_self_edge_right_space(
    {
      edges,
      sizes,
      rankdir,
      self_edge_size_pt: @node_geometry.SELF_EDGE_SIZE_PT,
      self_edge_label_width_for: @label_metrics.self_edge_label_width_pt,
      port_side_mask_for:
        (node, port) => port_side_mask_for_self_edge(node, port, port_maps),
    },
  )
}
