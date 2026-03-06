///|
/// X-position port geometry and offset helpers.

fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  @positioning.build_port_offsets_for_nodes(
    nodes,
    output_sizes,
    (node, rankdir) => {
      let record_orientation = record_layout_orientation(rankdir)
      node_size(node, record_orientation)
    },
    (node, origin, base_size, rankdir) => {
      let record_orientation = record_layout_orientation(rankdir)
      let label = label_text(node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        html_ports(node, origin, base_size)
      } else if is_record_shape(node) {
        record_ports(node, origin, base_size, record_orientation)
      } else {
        Map::new()
      }
    },
    layout_port_offset,
    swap_node_size,
  )
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
  }
}

fn compass_port_point(
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
    compass_uses_shape_clipping,
    (shape_node, size, shape_compass, shape_rankdir) =>
      @edge_spline.compass_port_point_on_shape(
        shape_node,
        @edge_spline.point(0.0, 0.0),
        size,
        shape_compass,
        shape_rankdir,
      ),
    layout_port_offset,
  )
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  let node = nodes_by_name.get(node_name)
  let unrotated = compass_port_point(node_name, node, compass, sizes, RankDir::TB)
  match node {
    Some(value) =>
      if is_record_shape(value) || @html_label.is_html_label_text(label_text(value)) {
        // Preserve record/html order behavior for explicit label ports.
        unrotated.x
      } else {
        // Graphviz parity: make_edge_pairs consumes compassPort rankdir-rotated
        // ED_{tail,head}_port.p.x for non-record compass-only endpoints.
        layout_port_offset(unrotated, rankdir).x
      }
    None => layout_port_offset(unrotated, rankdir).x
  }
}

///|
fn edge_port_offset(
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
      compass_port_offset(
        compass,
        node_name,
        sizes,
        rankdir,
        nodes_by_name,
      ),
  )
}
