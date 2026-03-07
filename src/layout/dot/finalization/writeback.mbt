///|
/// Final layout writeback: emit graph/node/edge geometry and label positions
/// from the internal layout tree onto Graphviz attributes.

///|
fn should_write_bbox(graph : @cgraph.Graph) -> Bool {
  if graph.is_root() {
    return true
  }
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn set_edge_label_pos_if_present(
  edge : @cgraph.Edge,
  label_attr : String,
  pos_attr : String,
  pos : @geom.Point?,
) -> Unit {
  match pos {
    Some(value) =>
      match edge.get_attr(label_attr) {
        Some(text) => if text != "" { edge.set_attr(pos_attr, @shared.format_point(value)) }
        None => ()
      }
    None => ()
  }
}

///|
fn apply_graph_output_attrs(layout : @shared.LayoutTree) -> @shared.RecordOrientation {
  let graph = layout.graph
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let write_bb = should_write_bbox(graph)
  if write_bb {
    graph.set_attr("bb", @shared.format_rect(layout.bbox))
  }
  if write_bb {
    match @label_metrics.graph_label_metrics(graph) {
      Some(metrics) => {
        graph.set_attr("lwidth", @shared.format_fixed(metrics.width_pt / 72.0, 2))
        graph.set_attr("lheight", @shared.format_fixed(metrics.height_pt / 72.0, 2))
      }
      None => ()
    }
  }
  match layout.label_pos {
    Some(pos) => graph.set_attr("lp", @shared.format_point(pos))
    None => ()
  }
  record_orientation
}

///|
fn apply_node_output_attrs(
  nodes : Array[@shared.DotLayoutNode],
  record_orientation : @shared.RecordOrientation,
) -> Unit {
  for node_layout in nodes {
    let node = node_layout.node
    let output_pos : @geom.Point = match node.get_attr("shape") {
      // Graphviz rounds star-node centroids up at the 0.001 boundary.
      Some(shape) if shape.to_lower() == "star" =>
        { x: node_layout.pos.x, y: node_layout.pos.y + 0.0005 }
      _ => node_layout.pos
    }
    node.set_attr("pos", @shared.format_point(output_pos))
    node.set_attr("width", @shared.format_dim(node_layout.width_in))
    node.set_attr("height", @shared.format_dim(node_layout.height_in))
    let is_mrecord = match node.get_attr("shape") {
      Some(value) => value.to_lower() == "mrecord"
      None => false
    }
    if @record_geometry.is_record_shape(node) &&
      !is_mrecord &&
      !@html_label.is_html_label_text(@label_attrs.label_text(node)) {
      let size = @node_primitives.node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = @record_layout.record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", @shared.format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", @shared.format_point(pos))
      None => ()
    }
    match node_layout.xlabel_pos {
      Some(pos) => node.set_attr("xlp", @shared.format_point(pos))
      None => ()
    }
  }
}

///|
fn apply_edge_output_attrs(
  graph : @cgraph.Graph,
  edges : Array[@shared.DotLayoutEdge],
) -> Unit {
  for edge_layout in edges {
    let edge = edge_layout.edge
    // Graphviz parity: omit e/s markers when arrowhead/arrowtail is none.
    let include_tail = @edge_semantics.edge_has_tail_marker(edge, graph.kind())
    let include_head = @edge_semantics.edge_has_head_marker(edge, graph.kind())
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{@shared.format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{@shared.format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(@shared.format_point(point))
      }
      segments.push(parts.join(" "))
    }
    edge.set_attr("pos", segments.join(";"))
    set_edge_label_pos_if_present(edge, "label", "lp", edge_layout.label_pos)
    set_edge_label_pos_if_present(
      edge,
      "headlabel",
      "head_lp",
      edge_layout.head_label_pos,
    )
    set_edge_label_pos_if_present(
      edge,
      "taillabel",
      "tail_lp",
      edge_layout.tail_label_pos,
    )
    set_edge_label_pos_if_present(edge, "xlabel", "xlp", edge_layout.xlabel_pos)
  }
}

///|
/// Graphviz parity: final writeback preserves Graphviz attribute emission order
/// for graph/node/edge geometry and label positions.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_layout_tree_writeback(layout : @shared.LayoutTree) -> Unit {
  let record_orientation = apply_graph_output_attrs(layout)
  apply_node_output_attrs(layout.nodes, record_orientation)
  apply_edge_output_attrs(layout.graph, layout.edges)
  for subgraph in layout.subgraphs {
    apply_layout_tree_writeback(subgraph)
  }
}
