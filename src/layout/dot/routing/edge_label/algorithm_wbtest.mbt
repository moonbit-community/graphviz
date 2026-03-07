///|
fn assert_close(actual : Double, expected : Double, eps? : Double = 0.000001) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps=eps)
  assert_close(actual.y, expected.y, eps=eps)
}

///|
fn require_point_with_tangent(
  value : PointWithTangent?,
  label : String,
) -> PointWithTangent raise {
  match value {
    Some(point) => point
    None => fail("\{label}: expected point with tangent")
  }
}

///|
fn straight_spline_points() -> Array[@geom.Point] {
  [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(3.0, 0.0),
    @edge_spline.point(6.0, 0.0),
    @edge_spline.point(9.0, 0.0),
  ]
}

///|
fn straight_spline() -> @geom.Spline {
  { start: None, end: None, points: straight_spline_points() }
}

///|
fn straight_spline_with_markers() -> @geom.Spline {
  {
    start: Some(@edge_spline.point(-1.0, 0.0)),
    end: Some(@edge_spline.point(10.0, 0.0)),
    points: straight_spline_points(),
  }
}

///|
fn layout_edge(edge : @cgraph.Edge, spline : @geom.Spline) -> DotLayoutEdge {
  {
    edge,
    splines: [spline],
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }
}

///|
test "sample_spline_points and spline label helpers follow arc length" {
  let samples = sample_spline_points(straight_spline_points(), 3)
  assert_eq(samples.length(), 4)
  assert_point_close(samples[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(samples[1], @edge_spline.point(3.0, 0.0), eps=0.001)
  assert_point_close(samples[2], @edge_spline.point(6.0, 0.0), eps=0.001)
  assert_point_close(samples[3], @edge_spline.point(9.0, 0.0), eps=0.001)

  let midpoint = require_point_with_tangent(
    spline_label_pos_with_samples(samples),
    "midpoint",
  )
  assert_point_close(midpoint.pos, @edge_spline.point(4.5, 0.0), eps=0.001)
  assert_point_close(midpoint.tangent, @edge_spline.point(1.0, 0.0))

  let axis_hit = require_point_with_tangent(
    spline_label_pos_at_samples(samples, 6.0, true),
    "axis-hit",
  )
  assert_point_close(axis_hit.pos, @edge_spline.point(6.0, 0.0), eps=0.001)
  assert_point_close(axis_hit.tangent, @edge_spline.point(1.0, 0.0))
}

///|
test "port_label_points respects marker fallback semantics" {
  let spline = straight_spline_with_markers()

  let head_marker = require_point_with_tangent(
    port_label_points(spline, true, true),
    "head-marker",
  )
  assert_point_close(head_marker.pos, @edge_spline.point(10.0, 0.0))
  assert_point_close(head_marker.tangent, @edge_spline.point(9.0, 0.0))

  let head_bezier = require_point_with_tangent(
    port_label_points(spline, true, false),
    "head-bezier",
  )
  assert_point_close(head_bezier.pos, @edge_spline.point(9.0, 0.0))
  assert_point_close(head_bezier.tangent, @edge_spline.point(8.1, 0.0), eps=0.01)

  let tail_marker = require_point_with_tangent(
    port_label_points(spline, false, true),
    "tail-marker",
  )
  assert_point_close(tail_marker.pos, @edge_spline.point(-1.0, 0.0))
  assert_point_close(tail_marker.tangent, @edge_spline.point(0.0, 0.0))

  let tail_bezier = require_point_with_tangent(
    port_label_points(spline, false, false),
    "tail-bezier",
  )
  assert_point_close(tail_bezier.pos, @edge_spline.point(0.0, 0.0))
  assert_point_close(tail_bezier.tangent, @edge_spline.point(0.9, 0.0), eps=0.01)
}

///|
test "port_label_params applies defaults parse fallback and min clamp" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-999")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-180.0, 2.0)))

  edge.set_attr("labelangle", "oops")
  edge.set_attr("labeldistance", "oops")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 1.0)))
}

///|
test "flat and vnode label position helpers keep rankdir-specific offsets" {
  let flat = flat_edge_label_pos_simple(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(20.0, 0.0),
    3.0,
    5.0,
    8.0,
    4.0,
  )
  assert_point_close(flat, @edge_spline.point(9.0, 6.0))

  let vnode = @edge_spline.point(10.0, 20.0)
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::TB),
    @edge_spline.point(16.0, 20.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::LR),
    @edge_spline.point(14.0, 20.0),
  )
}

///|
test "expand_bbox_for_label_pos only grows when both center and metrics exist" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let metrics : LabelExtent = { width: 6.0, height: 4.0 }

  let expanded =
    expand_bbox_for_label_pos(bbox, Some(@edge_spline.point(12.0, 5.0)), Some(metrics))

  assert_eq(expanded, { llx: 0.0, lly: 0.0, urx: 15.0, ury: 10.0 })
  assert_eq(expand_bbox_for_label_pos(bbox, None, Some(metrics)), bbox)
  assert_eq(
    expand_bbox_for_label_pos(bbox, Some(@edge_spline.point(12.0, 5.0)), None),
    bbox,
  )
}

///|
test "edge_midpoint_for_layout matches straight-edge midpoint selection" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let edge_layout = layout_edge(edge, straight_spline())

  let polyline_mid = match edge_midpoint_for_layout(edge_layout, false) {
    Some(point) => point
    None => fail("expected polyline midpoint")
  }
  let spline_mid = match edge_midpoint_for_layout(edge_layout, true) {
    Some(point) => point
    None => fail("expected spline midpoint")
  }

  assert_point_close(polyline_mid, @edge_spline.point(4.5, 0.0), eps=0.01)
  assert_point_close(spline_mid, @edge_spline.point(4.5, 0.0), eps=0.01)
}

///|
fn make_edge_label_pos_input(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  rankdir : @rankdir.RankDir,
  label_rank_y? : Double? = None,
  label_rank_x? : Double? = None,
  apply_label_pad? : Bool = false,
  nodesep_pt? : Double = 10.0,
  label_pad_boost? : Double = 0.0,
  tail_clip? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_clip? : @geom.Point = @edge_spline.point(9.0, 0.0),
) -> EdgeLabelPosInput {
  {
    edge,
    spline,
    tail_clip,
    head_clip,
    rankdir,
    label_rank_y,
    label_rank_x,
    apply_label_pad,
    nodesep_pt,
    label_pad_boost,
  }
}

///|
test "edge_label_pos_from_input uses rank axes and width-based pad on ranked labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let input = make_edge_label_pos_input(
    edge,
    straight_spline(),
    @rankdir.RankDir::TB,
    label_rank_y=Some(10.0),
    label_rank_x=Some(7.0),
    nodesep_pt=20.0,
    label_pad_boost=1.0,
  )

  let explicit_axis_pos = match edge_label_pos_from_input(
    input,
    _ => Some({ width: 8.0, height: 4.0 }),
    12.0,
  ) {
    Some(value) => value
    None => fail("expected explicit-axis label pos")
  }
  assert_point_close(explicit_axis_pos, @edge_spline.point(11.0, 10.0))

  let vertical_spline : @geom.Spline = {
    start: None,
    end: None,
    points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(0.0, 6.6666667),
      @edge_spline.point(0.0, 13.3333333),
      @edge_spline.point(0.0, 20.0),
    ],
  }
  let padded_input = make_edge_label_pos_input(
    edge,
    vertical_spline,
    @rankdir.RankDir::TB,
    label_rank_y=Some(10.0),
    nodesep_pt=20.0,
    label_pad_boost=1.0,
    tail_clip=@edge_spline.point(0.0, 0.0),
    head_clip=@edge_spline.point(0.0, 20.0),
  )
  let padded_pos = match edge_label_pos_from_input(
    padded_input,
    _ => Some({ width: 12.0, height: 4.0 }),
    10.0,
  ) {
    Some(value) => value
    None => fail("expected padded label pos")
  }
  assert_point_close(padded_pos, @edge_spline.point(11.4, 10.0), eps=0.001)
}

///|
test "edge_label_pos_from_input maps axes for LR and skips metric offset on self edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let edge = graph.edge(a, a)
  let input = make_edge_label_pos_input(
    edge,
    straight_spline(),
    @rankdir.RankDir::LR,
    label_rank_y=Some(10.0),
    label_rank_x=Some(7.0),
    label_pad_boost=5.0,
  )

  let pos = match edge_label_pos_from_input(
    input,
    _ => Some({ width: 8.0, height: 4.0 }),
    12.0,
  ) {
    Some(value) => value
    None => fail("expected self-edge label pos")
  }

  assert_point_close(pos, @edge_spline.point(10.0, 7.0))
}

///|
test "edge_label_pos_from_input offsets unranked labels along the segment normal" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let input = make_edge_label_pos_input(
    edge,
    straight_spline(),
    @rankdir.RankDir::TB,
    label_pad_boost=1.5,
  )

  let pos = match edge_label_pos_from_input(
    input,
    _ => Some({ width: 8.0, height: 4.0 }),
    12.0,
  ) {
    Some(value) => value
    None => fail("expected unranked label pos")
  }

  assert_point_close(pos, @edge_spline.point(4.5, 3.5), eps=0.001)
}

///|
test "port_label_pos_from_points rotates the tangent direction by angle and distance" {
  let pos = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(4.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(pos, @edge_spline.point(1.0, 8.0), eps=0.001)
}

///|
test "port_label_pos_from_points follows edge-local angle and distance scale" {
  let horizontal = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(5.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(horizontal, @edge_spline.point(1.0, 8.0), eps=0.001)

  let vertical = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(1.0, 6.0),
    0.0,
    0.5,
    4.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(vertical, @edge_spline.point(1.0, 4.0), eps=0.001)
}
