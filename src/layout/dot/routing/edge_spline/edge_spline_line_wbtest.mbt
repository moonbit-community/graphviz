///|
test "edge_spline_for_line linearizes unlabeled degenerate cubics but preserves labeled ones" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let plain = graph.edge(tail, head)
  let labeled = graph.edge(tail, head, name="labeled")
  labeled.set_attr("label", "mid")

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let plain_spline = edge_spline_for_line(
    plain,
    point(0.0, 0.0),
    point(9.0, 0.0),
    point(0.0, 0.0),
    point(9.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, 0.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::TB,
    0.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )
  let labeled_spline = edge_spline_for_line(
    labeled,
    point(0.0, 0.0),
    point(9.0, 0.0),
    point(0.0, 0.0),
    point(9.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, 0.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::TB,
    0.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )

  assert_eq(plain_spline.start, None)
  assert_eq(plain_spline.end, None)
  assert_eq(plain_spline.points, [
    point(0.0, 0.0),
    point(3.0, 0.0),
    point(6.0, 0.0),
    point(9.0, 0.0),
  ])

  assert_eq(labeled_spline.start, None)
  assert_eq(labeled_spline.end, None)
  assert_eq(labeled_spline.points, [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(9.0, 0.0),
    point(9.0, 0.0),
  ])
}

///|
test "edge_spline_for_line uses linear control points when a cluster bbox is present" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let routed_spline = edge_spline_for_line(
    edge,
    point(0.0, 12.0),
    point(0.0, 0.0),
    point(0.0, 12.0),
    point(0.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, -1.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::TB,
    0.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )
  let linearized_spline = edge_spline_for_line(
    edge,
    point(0.0, 12.0),
    point(0.0, 0.0),
    point(0.0, 12.0),
    point(0.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, -1.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::TB,
    0.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=Some({ llx: -1.0, lly: -1.0, urx: 1.0, ury: 13.0 }),
    head_cluster_bbox=None,
  )

  assert_eq(routed_spline.start, None)
  assert_eq(routed_spline.end, None)
  assert_eq(routed_spline.points, [
    point(0.0, 12.0),
    point(0.0, 12.0),
    point(0.0, 16.0 / 3.0),
    point(0.0, 0.0),
  ])

  assert_eq(linearized_spline.start, None)
  assert_eq(linearized_spline.end, None)
  assert_eq(linearized_spline.points, [
    point(0.0, 12.0),
    point(0.0, 8.0),
    point(0.0, 4.0),
    point(0.0, 0.0),
  ])
}

///|
test "edge_spline_for_line offsets curved lines along the rankdir-selected perpendicular" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)
  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)

  let tb_spline = edge_spline_for_line(
    edge,
    point(0.0, 0.0),
    point(9.0, 0.0),
    point(0.0, 0.0),
    point(9.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, 0.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::TB,
    2.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )
  let lr_spline = edge_spline_for_line(
    edge,
    point(0.0, 0.0),
    point(0.0, 9.0),
    point(0.0, 0.0),
    point(0.0, 9.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(0.0, 0.0),
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    @rankdir.RankDir::LR,
    2.0,
    1.0,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )

  assert_eq(tb_spline.start, None)
  assert_eq(tb_spline.end, None)
  assert_eq(tb_spline.points, [
    point(0.0, -2.0),
    point(3.0, -2.0),
    point(6.0, -2.0),
    point(9.0, -2.0),
  ])

  assert_eq(lr_spline.start, None)
  assert_eq(lr_spline.end, None)
  assert_eq(lr_spline.points, [
    point(-2.0, 0.0),
    point(-2.0, 3.0),
    point(-2.0, 6.0),
    point(-2.0, 9.0),
  ])
}
