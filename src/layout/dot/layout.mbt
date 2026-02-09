///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
/// Graphviz parity: dot layout orchestration aligned to refs/graphviz/lib/dotgen/dotinit.c
/// (dot_layout/doDot) + lib/common/postproc.c (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  validate_layout_graph(graph)
  reset_label_caches()
  let prep = prepare_layout_inputs(graph, opts)
  let rank_stage = compute_dot_rank_stage(graph, prep)
  let positions_state = compute_dot_position_stage(graph, prep, rank_stage)
  let routing_stage =
    compute_dot_routing_stage(graph, prep, rank_stage, positions_state)
  finalize_layout_graph(
    graph,
    prep.nodes,
    routing_stage.nodes_out,
    routing_stage.edges_out,
    prep.rankdir,
    prep.splines,
    rank_stage.rank_data.all_ranks,
    rank_stage.rank_data.ranks,
    prep.sizes,
    positions_state.cluster_ln_x,
    positions_state.cluster_rn_x,
    positions_state.rank_y,
    positions_state.rank_ht1,
    positions_state.rank_ht2,
    rank_stage.rank_heights.nodesep_pt,
    routing_stage.port_pad_below,
    routing_stage.port_pad_above,
  )
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let arrow_is_none = (value : String?) => {
    match value {
      Some(v) => v.trim().to_lower() == "none"
      None => false
    }
  }
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    record_layout_orientation(graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", format_dim(node_layout.width_in))
    node.set_attr("height", format_dim(node_layout.height_in))
    if is_record_shape(node) && !@html_label.is_html_label_text(label_text(node)) {
      let size = node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
    match node_layout.xlabel_pos {
      Some(pos) => node.set_attr("xlp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let dir = edge_dir_for(edge, self.graph.kind())
    // Graphviz parity: omit e/s markers when arrowhead/arrowtail is none.
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => !arrow_is_none(edge.get_attr("arrowtail"))
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => !arrow_is_none(edge.get_attr("arrowhead"))
      _ => false
    }
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    match edge_layout.label_pos {
      Some(pos) => edge.set_attr("lp", format_point(pos))
      None => ()
    }
    match edge_layout.head_label_pos {
      Some(pos) => edge.set_attr("head_lp", format_point(pos))
      None => ()
    }
    match edge_layout.tail_label_pos {
      Some(pos) => edge.set_attr("tail_lp", format_point(pos))
      None => ()
    }
    match edge_layout.xlabel_pos {
      Some(pos) => edge.set_attr("xlp", format_point(pos))
      None => ()
    }
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
