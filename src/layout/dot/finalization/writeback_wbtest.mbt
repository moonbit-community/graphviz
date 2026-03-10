///|
fn writeback_make_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  label_pos? : @geom.Point? = None,
  nodes? : Array[DotLayoutNode] = [],
  edges? : Array[DotLayoutEdge] = [],
  subgraphs? : Array[LayoutTree] = [],
) -> LayoutTree {
  { graph, bbox, label_pos, nodes, edges, subgraphs }
}

///|
fn writeback_make_node_layout(
  node : @cgraph.Node,
  pos : @geom.Point,
  width_in : Double,
  height_in : Double,
  label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutNode {
  { node, pos, width_in, height_in, label_pos, xlabel_pos }
}

///|
fn writeback_make_edge_layout(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  label_pos? : @geom.Point? = None,
  head_label_pos? : @geom.Point? = None,
  tail_label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutEdge {
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
test "apply_layout_tree_writeback writes bbox by graph role and edge label attrs conditionally" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let plain = graph.subgraph(name="group_0")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("dir", "none")
  edge.set_attr("label", "L")
  edge.set_attr("taillabel", "T")
  edge.set_attr("headlabel", "")
  edge.set_attr("xlabel", "X")

  let node_layout = writeback_make_node_layout(
    a,
    { x: 10.0, y: 20.0 },
    1.0,
    0.5,
    xlabel_pos=Some({ x: 12.0, y: 24.0 }),
  )
  let spline : @geom.Spline = {
    start: Some({ x: -1.0, y: -1.0 }),
    end: Some({ x: 11.0, y: 11.0 }),
    points: [
      { x: 0.0, y: 0.0 },
      { x: 3.0, y: 0.0 },
      { x: 6.0, y: 0.0 },
      { x: 9.0, y: 0.0 },
    ],
  }
  let edge_layout = writeback_make_edge_layout(
    edge,
    spline,
    label_pos=Some({ x: 4.0, y: 5.0 }),
    head_label_pos=Some({ x: 7.0, y: 8.0 }),
    tail_label_pos=Some({ x: 1.0, y: 2.0 }),
    xlabel_pos=Some({ x: 6.0, y: 7.0 }),
  )
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    nodes=[node_layout],
    edges=[edge_layout],
    subgraphs=[
      writeback_make_layout_tree(cluster, {
        llx: 1.0,
        lly: 1.0,
        urx: 2.0,
        ury: 2.0,
      }),
      writeback_make_layout_tree(plain, {
        llx: 3.0,
        lly: 3.0,
        urx: 4.0,
        ury: 4.0,
      }),
    ],
  )

  apply_layout_tree_writeback(layout)

  assert_eq(graph.get_attr("bb"), Some(format_rect(layout.bbox)))
  assert_eq(cluster.get_attr("bb"), Some("1,1,2,2"))
  assert_eq(plain.get_attr("bb"), None)

  assert_eq(a.get_attr("pos"), Some("10,20"))
  assert_eq(a.get_attr("width"), Some("1"))
  assert_eq(a.get_attr("height"), Some("0.5"))
  assert_eq(a.get_attr("xlp"), Some("12,24"))

  assert_eq(edge.get_attr("pos"), Some("0,0 3,0 6,0 9,0"))
  assert_eq(edge.get_attr("lp"), Some("4,5"))
  assert_eq(edge.get_attr("head_lp"), None)
  assert_eq(edge.get_attr("tail_lp"), Some("1,2"))
  assert_eq(edge.get_attr("xlp"), Some("6,7"))
}

///|
test "apply_layout_tree_writeback writes root and cluster label attrs recursively" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster Label")

  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 20.0, ury: 10.0 },
    label_pos=Some({ x: 7.0, y: 8.0 }),
    subgraphs=[
      writeback_make_layout_tree(
        cluster,
        { llx: 1.0, lly: 2.0, urx: 11.0, ury: 12.0 },
        label_pos=Some({ x: 6.0, y: 9.0 }),
      ),
    ],
  )

  apply_layout_tree_writeback(layout)

  let root_metrics = match @label_metrics.graph_label_metrics(graph) {
    Some(value) => value
    None => fail("expected root graph label metrics")
  }
  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }

  assert_eq(graph.get_attr("bb"), Some("0,0,20,10"))
  assert_eq(
    graph.get_attr("lwidth"),
    Some(format_fixed(root_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    graph.get_attr("lheight"),
    Some(format_fixed(root_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(graph.get_attr("lp"), Some("7,8"))

  assert_eq(cluster.get_attr("bb"), Some("1,2,11,12"))
  assert_eq(
    cluster.get_attr("lwidth"),
    Some(format_fixed(cluster_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    cluster.get_attr("lheight"),
    Some(format_fixed(cluster_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(cluster.get_attr("lp"), Some("6,9"))
}

///|
test "apply_layout_tree_writeback writes graph label metrics star node rounding and arrow markers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let star = graph.node("star")
  star.set_attr("shape", "star")
  let head = graph.node("head")
  let edge = graph.edge(star, head)
  edge.set_attr("dir", "both")

  let star_layout = writeback_make_node_layout(
    star,
    { x: 10.0, y: 20.0 },
    1.0,
    0.5,
  )
  let edge_layout = writeback_make_edge_layout(edge, {
    start: Some({ x: -1.0, y: -2.0 }),
    end: Some({ x: 12.0, y: 13.0 }),
    points: [
      { x: 0.0, y: 0.0 },
      { x: 2.0, y: 1.0 },
      { x: 4.0, y: 2.0 },
      { x: 6.0, y: 3.0 },
    ],
  })
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 5.0, y: 9.0 }),
    nodes=[star_layout],
    edges=[edge_layout],
  )

  apply_layout_tree_writeback(layout)

  let graph_metrics = match @label_metrics.graph_label_metrics(graph) {
    Some(value) => value
    None => fail("expected root graph label metrics")
  }
  assert_eq(
    graph.get_attr("lwidth"),
    Some(format_fixed(graph_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    graph.get_attr("lheight"),
    Some(format_fixed(graph_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(graph.get_attr("lp"), Some("5,9"))
  assert_eq(star.get_attr("pos"), Some(format_point({ x: 10.0, y: 20.0005 })))
  assert_eq(edge.get_attr("pos"), Some("s,-1,-2 e,12,13 0,0 2,1 4,2 6,3"))
}

///|
test "apply_layout_tree_writeback omits disabled arrow markers independently" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let tail_disabled = graph.edge(a, b)
  let head_disabled = graph.edge(a, b, name="head_disabled")
  tail_disabled.set_attr("dir", "both")
  tail_disabled.set_attr("arrowtail", "none")
  head_disabled.set_attr("dir", "both")
  head_disabled.set_attr("arrowhead", "none")

  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=[
      writeback_make_edge_layout(tail_disabled, {
        start: Some({ x: -1.0, y: -2.0 }),
        end: Some({ x: 12.0, y: 13.0 }),
        points: [
          { x: 0.0, y: 0.0 },
          { x: 2.0, y: 1.0 },
          { x: 4.0, y: 2.0 },
          { x: 6.0, y: 3.0 },
        ],
      }),
      writeback_make_edge_layout(head_disabled, {
        start: Some({ x: -3.0, y: -4.0 }),
        end: Some({ x: 14.0, y: 15.0 }),
        points: [
          { x: 1.0, y: 0.0 },
          { x: 3.0, y: 1.0 },
          { x: 5.0, y: 2.0 },
          { x: 7.0, y: 3.0 },
        ],
      }),
    ],
  )

  apply_layout_tree_writeback(layout)

  assert_eq(tail_disabled.get_attr("pos"), Some("e,12,13 0,0 2,1 4,2 6,3"))
  assert_eq(head_disabled.get_attr("pos"), Some("s,-3,-4 1,0 3,1 5,2 7,3"))
}

///|
test "apply_layout_tree_writeback writes rects only for non-html non-mrecord record shapes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let record = graph.node("record")
  record.set_attr("shape", "record")
  record.set_attr("label", "<left>l|<right>r")
  let mrecord = graph.node("mrecord")
  mrecord.set_attr("shape", "mrecord")
  mrecord.set_attr("label", "<left>l|<right>r")
  let html_record = graph.node("html_record")
  html_record.set_attr("shape", "record")
  html_record.set_attr("label", "<<TABLE><TR><TD>x</TD></TR></TABLE>>")

  let record_layout = writeback_make_node_layout(
    record,
    { x: 10.0, y: 20.0 },
    2.0,
    1.0,
  )
  let mrecord_layout = writeback_make_node_layout(
    mrecord,
    { x: 40.0, y: 20.0 },
    2.0,
    1.0,
  )
  let html_record_layout = writeback_make_node_layout(
    html_record,
    { x: 70.0, y: 20.0 },
    2.0,
    1.0,
  )
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 100.0, ury: 40.0 },
    nodes=[record_layout, mrecord_layout, html_record_layout],
  )

  apply_layout_tree_writeback(layout)

  let size = @node_primitives.node_size_from_points(2.0 * 72.0, 1.0 * 72.0)
  let expected_rects = format_rects(
    @record_layout.record_rects(
      record,
      record_layout.pos,
      size,
      @layout_prep.record_layout_orientation(@rankdir.graph_rankdir(graph)),
    ),
  )

  assert_eq(record.get_attr("rects"), Some(expected_rects))
  assert_eq(mrecord.get_attr("rects"), None)
  assert_eq(html_record.get_attr("rects"), None)
}
