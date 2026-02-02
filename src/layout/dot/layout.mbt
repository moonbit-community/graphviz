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
  let rankdir = prep.rankdir
  let nodesep_in = prep.nodesep_in
  let ranksep_in = prep.ranksep_in
  let splines = prep.splines
  let nodes = prep.nodes
  let edges = prep.edges
  let has_port_edges = prep.has_port_edges
  let has_edge_labels = prep.has_edge_labels
  let node_order = prep.node_order
  let record_orientation = prep.record_orientation
  let output_sizes = prep.output_sizes
  let order_sizes = prep.order_sizes
  let sizes = prep.sizes
  let port_order_positions = prep.port_order_positions
  let port_order_contrib = prep.port_order_contrib
  let layout_rankdir = RankDir::TB
  let rank_data = compute_rank_data(graph, nodes, edges, has_edge_labels)
  let edge_tail = rank_data.edge_tail
  let edge_head = rank_data.edge_head
  let edge_reversed = rank_data.edge_reversed
  let ranks = rank_data.ranks
  let groups = rank_data.groups
  let rank_keys = rank_data.rank_keys
  let all_ranks = rank_data.all_ranks
  let self_edge_labels = rank_data.self_edge_labels
  dot_trace("layout_dot: ranks computed")
  dot_trace_edges(edges, edge_tail, edge_head, ranks)
  let rank_heights = compute_rank_heights(
    graph,
    edges,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    sizes,
    self_edge_labels,
    nodesep_in,
    ranksep_in,
    has_edge_labels,
  )
  let nodesep_pt = rank_heights.nodesep_pt
  let ranksep_pt = rank_heights.ranksep_pt
  let cluster_meta =
    compute_cluster_metadata(graph, nodes, edges, groups, ranks, node_order, edge_tail, edge_head)
  let has_clusters = cluster_meta.has_clusters
  let ordering = compute_ordering_and_vnodes(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
  )
  let vnode_info = ordering.vnode_info
  dot_trace("layout_dot: rank order computed")
  let positions_state =
    compute_positions(graph, prep, rank_data, rank_heights, cluster_meta, ordering)
  let x_groups = positions_state.x_groups
  let rank_y = positions_state.rank_y
  let positions = positions_state.positions
  let vnode_positions = positions_state.vnode_positions
  let flat_label_edge_vnodes = positions_state.flat_label_edge_vnodes
  let rank_ht1 = positions_state.rank_ht1
  let rank_ht2 = positions_state.rank_ht2
  let nodes_out =
    build_layout_nodes(nodes, positions, output_sizes, record_orientation)
  let port_maps =
    build_port_layout_maps(
      nodes_out,
      output_sizes,
      record_orientation,
      rankdir,
      has_port_edges,
    )
  let label_ports_map = port_maps.label_ports_map
  let label_ports_raw = port_maps.label_ports_raw
  let cluster_bboxes = compute_cluster_bboxes_for_routing(graph, nodes_out)
  let label_edge_counts = build_label_edge_counts(edges)
  let enable_complex_tuning = complex_tuning_enabled()
  let (port_pad_below, port_pad_above) =
    compute_port_padding(
      has_clusters,
      has_port_edges,
      edges,
      positions,
      label_ports_map,
    )
  let head_port_metrics =
    collect_head_port_metrics(
      edges,
      positions,
      sizes,
      label_ports_map,
      record_orientation,
      enable_complex_tuning,
    )
  let routing_context =
    prepare_routing_context(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
      ranks,
      ordering.ordered_groups,
      x_groups,
      nodesep_pt,
      vnode_info,
      vnode_positions,
      cluster_bboxes,
    )
  let edges_out =
    route_edges(
      graph,
      edges,
      ranks,
      sizes,
      record_orientation,
      rankdir,
      layout_rankdir,
      splines,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      ranksep_pt,
      has_clusters,
      label_ports_map,
      label_ports_raw,
      label_edge_counts,
      head_port_metrics,
      flat_label_edge_vnodes,
      routing_context,
      enable_complex_tuning,
    )
  dot_trace("layout_dot: edges routed")
  finalize_layout_graph(
    graph,
    nodes,
    nodes_out,
    edges_out,
    rankdir,
    all_ranks,
    ranks,
    nodesep_pt,
    port_pad_below,
    port_pad_above,
  )
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
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
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let dir = edge_dir_for(edge, self.graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
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
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
