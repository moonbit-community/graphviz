///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
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
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
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
fn layout_edge(
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
test "spline_label_pos_at_samples picks the y-axis crossing nearest the arc midpoint" {
  let samples = [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(4.0, 4.0),
    @edge_spline.point(8.0, 0.0),
    @edge_spline.point(12.0, 4.0),
  ]

  let axis_hit = require_point_with_tangent(
    spline_label_pos_at_samples(samples, 2.0, false),
    "y-axis-hit",
  )

  assert_point_close(axis_hit.pos, @edge_spline.point(6.0, 2.0), eps=0.001)
  assert_point_close(
    axis_hit.tangent,
    @edge_spline.point(0.70710678, -0.70710678),
    eps=0.001,
  )
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
  assert_point_close(
    head_bezier.tangent,
    @edge_spline.point(8.1, 0.0),
    eps=0.01,
  )

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
  assert_point_close(
    tail_bezier.tangent,
    @edge_spline.point(0.9, 0.0),
    eps=0.01,
  )
}

///|
test "port_label_points falls back to bezier samples when markers are requested but missing" {
  let spline = straight_spline()

  let head = require_point_with_tangent(
    port_label_points(spline, true, true),
    "head-fallback",
  )
  assert_point_close(head.pos, @edge_spline.point(9.0, 0.0))
  assert_point_close(head.tangent, @edge_spline.point(8.1, 0.0), eps=0.01)

  let tail = require_point_with_tangent(
    port_label_points(spline, false, true),
    "tail-fallback",
  )
  assert_point_close(tail.pos, @edge_spline.point(0.0, 0.0))
  assert_point_close(tail.tangent, @edge_spline.point(0.9, 0.0), eps=0.01)
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
test "port_label_params treats empty attrs as explicit defaults only when the other attr is present" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  edge.set_attr("labelangle", "")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-30")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-30.0, 1.0)))
}

///|
test "edge_label_rank_info uses the midpoint rank for long labeled edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_width = @edge_label_metrics.edge_mid_label_width_pt(edge)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  ranks["b"] = 6

  let info = match edge_label_rank_info(edge, ranks, label_width) {
    Some(value) => value
    None => fail("expected edge label rank info")
  }
  assert_eq(info.label_rank, 3)
  assert_eq(info.span, 5)
}

///|
test "edge_label_rank_info handles odd spans and ignores unlabeled one-rank-span and incomplete-rank edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let unlabeled = graph.edge(a, b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3
  assert_true(edge_label_rank_info(unlabeled, ranks, 0.0) is None)

  let short_edge = graph.edge(a, b)
  short_edge.set_attr("label", "mid")
  let short_info = match
    edge_label_rank_info(
      short_edge,
      ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    ) {
    Some(value) => value
    None => fail("expected odd-span label rank info")
  }
  assert_eq(short_info.label_rank, 1)
  assert_eq(short_info.span, 3)

  let short_span_ranks : Map[String, Int] = Map::new()
  short_span_ranks["a"] = 0
  short_span_ranks["b"] = 1
  assert_eq(
    edge_label_rank_info(
      short_edge,
      short_span_ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    )
    is None,
    true,
  )

  let incomplete_ranks : Map[String, Int] = Map::new()
  incomplete_ranks["a"] = 0
  assert_eq(
    edge_label_rank_info(
      short_edge,
      incomplete_ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    )
    is None,
    true,
  )
}

///|
test "edge_label_pos_from_vnode switches between width and height based on rankdir" {
  let vnode = @edge_spline.point(30.0, 40.0)

  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::TB),
    @edge_spline.point(36.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::BT),
    @edge_spline.point(36.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::LR),
    @edge_spline.point(34.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::RL),
    @edge_spline.point(34.0, 40.0),
  )
}

///|
test "flat_edge_label_pos_simple centers between clipped endpoints with asymmetric node widths" {
  let pos = flat_edge_label_pos_simple(
    @edge_spline.point(4.0, 10.0),
    @edge_spline.point(30.0, 10.0),
    6.0,
    5.0,
    8.0,
    6.0,
  )

  assert_point_close(pos, @edge_spline.point(17.5, 17.0))
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

  let expanded = expand_bbox_for_label_pos(
    bbox,
    Some(@edge_spline.point(12.0, 5.0)),
    Some(metrics),
  )

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
test "edge endpoint helpers prefer markers then point fallbacks and return None without splines" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let marker_layout = layout_edge(edge, straight_spline_with_markers())
  let point_layout = layout_edge(edge, straight_spline())
  let empty_layout : DotLayoutEdge = {
    edge,
    splines: [],
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }

  assert_eq(
    edge_tail_point_for_layout(marker_layout),
    Some(@edge_spline.point(-1.0, 0.0)),
  )
  assert_eq(
    edge_head_point_for_layout(marker_layout),
    Some(@edge_spline.point(10.0, 0.0)),
  )
  assert_eq(
    edge_tail_point_for_layout(point_layout),
    Some(@edge_spline.point(0.0, 0.0)),
  )
  assert_eq(
    edge_head_point_for_layout(point_layout),
    Some(@edge_spline.point(9.0, 0.0)),
  )
  assert_eq(edge_tail_point_for_layout(empty_layout), None)
  assert_eq(edge_head_point_for_layout(empty_layout), None)
}

///|
test "edge_midpoint_for_layout returns the collapsed endpoint when tail and head coincide" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let same = @edge_spline.point(4.0, 4.0)
  let collapsed_spline : @geom.Spline = {
    start: Some(same),
    end: Some(same),
    points: [
      same,
      @edge_spline.point(6.0, 8.0),
      @edge_spline.point(8.0, 6.0),
      same,
    ],
  }
  let edge_layout = layout_edge(edge, collapsed_spline)

  assert_eq(edge_midpoint_for_layout(edge_layout, false), Some(same))
  assert_eq(edge_midpoint_for_layout(edge_layout, true), Some(same))
}

///|
test "dotneato_closest_point handles empty point sets and short splines" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let empty_layout : DotLayoutEdge = {
    edge,
    splines: [],
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }
  let no_points_layout = layout_edge(edge, {
    start: None,
    end: None,
    points: [],
  })
  let short_layout = layout_edge(edge, {
    start: None,
    end: None,
    points: [
      @edge_spline.point(2.0, 1.0),
      @edge_spline.point(8.0, 5.0),
      @edge_spline.point(12.0, 7.0),
    ],
  })

  assert_eq(
    dotneato_closest_point(empty_layout, @edge_spline.point(5.0, 5.0)),
    None,
  )
  assert_eq(
    dotneato_closest_point(no_points_layout, @edge_spline.point(5.0, 5.0)),
    None,
  )
  assert_eq(
    dotneato_closest_point(short_layout, @edge_spline.point(9.0, 6.0)),
    Some(@edge_spline.point(2.0, 1.0)),
  )
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

  let explicit_axis_pos = match
    edge_label_pos_from_input(
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
  let padded_pos = match
    edge_label_pos_from_input(
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

  let pos = match
    edge_label_pos_from_input(
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

  let pos = match
    edge_label_pos_from_input(
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
test "edge_label_pos_from_input falls back on ranked axis misses and applies negative RL offset" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let input = make_edge_label_pos_input(
    edge,
    straight_spline(),
    @rankdir.RankDir::RL,
    label_rank_y=Some(100.0),
    apply_label_pad=true,
    nodesep_pt=20.0,
    label_pad_boost=1.0,
  )

  let pos = match
    edge_label_pos_from_input(
      input,
      _ => Some({ width: 12.0, height: 4.0 }),
      100.0,
    ) {
    Some(value) => value
    None => fail("expected RL ranked fallback label pos")
  }

  assert_point_close(pos, @edge_spline.point(-2.9, 0.0), eps=0.001)
}

///|
test "edge_label_pos_from_input maps label_rank_x without rank_y in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let input = make_edge_label_pos_input(
    edge,
    straight_spline(),
    @rankdir.RankDir::LR,
    label_rank_x=Some(7.0),
  )

  let pos = match edge_label_pos_from_input(input, _ => None, 12.0) {
    Some(value) => value
    None => fail("expected LR x-axis-only label pos")
  }

  assert_point_close(pos, @edge_spline.point(4.5, 7.0), eps=0.001)
}

///|
test "edge_label_pos_from_input keeps the base position for multi-segment diagonal splines" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let diagonal_spline : @geom.Spline = {
    start: None,
    end: None,
    points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(1.0, 1.0),
      @edge_spline.point(2.0, 2.0),
      @edge_spline.point(3.0, 3.0),
      @edge_spline.point(4.0, 4.0),
      @edge_spline.point(5.0, 5.0),
      @edge_spline.point(6.0, 6.0),
    ],
  }
  let input = make_edge_label_pos_input(
    edge,
    diagonal_spline,
    @rankdir.RankDir::TB,
    label_pad_boost=2.0,
    tail_clip=@edge_spline.point(0.0, 0.0),
    head_clip=@edge_spline.point(6.0, 6.0),
  )

  let pos = match
    edge_label_pos_from_input(
      input,
      _ => Some({ width: 10.0, height: 6.0 }),
      12.0,
    ) {
    Some(value) => value
    None => fail("expected diagonal label pos")
  }

  assert_point_close(pos, @edge_spline.point(3.0, 3.0), eps=0.001)
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

///|
test "edge_port_label_pos returns None without attrs or usable spline geometry" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let spline = straight_spline_with_markers()

  assert_eq(
    edge_port_label_pos(
      { edge, spline, is_head: false },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ),
    None,
  )

  edge.set_attr("labeldistance", "2")
  let short_spline : @geom.Spline = {
    start: None,
    end: None,
    points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(1.0, 0.0),
      @edge_spline.point(2.0, 0.0),
    ],
  }
  assert_eq(
    edge_port_label_pos(
      { edge, spline: short_spline, is_head: true },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ),
    None,
  )
}

///|
test "edge_port_label_pos uses marker endpoints when dir enables both arrow markers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("dir", "both")
  edge.set_attr("labelangle", "30")
  edge.set_attr("labeldistance", "1.4")
  let spline = straight_spline_with_markers()

  let tail = match
    edge_port_label_pos(
      { edge, spline, is_head: false },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ) {
    Some(value) => value
    None => fail("expected tail port label pos")
  }
  let head = match
    edge_port_label_pos(
      { edge, spline, is_head: true },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ) {
    Some(value) => value
    None => fail("expected head port label pos")
  }

  let expected_tail = port_label_pos_from_points(
    @edge_spline.point(-1.0, 0.0),
    @edge_spline.point(0.0, 0.0),
    30.0,
    1.4,
    10.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  let expected_head = port_label_pos_from_points(
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(9.0, 0.0),
    30.0,
    1.4,
    10.0,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(tail, expected_tail, eps=0.001)
  assert_point_close(head, expected_head, eps=0.001)
}

///|
test "edge_port_label_pos_for_dot uses bezier fallback and dot defaults when markers are absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("dir", "none")
  edge.set_attr("labeldistance", "2")
  let spline = straight_spline_with_markers()

  let tail = match
    edge_port_label_pos_for_dot({ edge, spline, is_head: false }) {
    Some(value) => value
    None => fail("expected tail port label pos")
  }
  let head = match
    edge_port_label_pos_for_dot({ edge, spline, is_head: true }) {
    Some(value) => value
    None => fail("expected head port label pos")
  }

  let expected_tail = port_label_pos_from_points(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(0.9, 0.0),
    @node_geometry.PORT_LABEL_ANGLE_DEG,
    2.0,
    @node_geometry.PORT_LABEL_DISTANCE_PT,
    @node_geometry.GRAPHVIZ_PI,
  )
  let expected_head = port_label_pos_from_points(
    @edge_spline.point(9.0, 0.0),
    @edge_spline.point(8.1, 0.0),
    @node_geometry.PORT_LABEL_ANGLE_DEG,
    2.0,
    @node_geometry.PORT_LABEL_DISTANCE_PT,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(tail, expected_tail, eps=0.001)
  assert_point_close(head, expected_head, eps=0.001)
}

///|
test "expand_bbox_for_edge_labels skips flat non-self mid labels without flat-label vnodes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [
      layout_edge(
        edge,
        straight_spline(),
        label_pos=Some(@edge_spline.point(25.0, 25.0)),
      ),
    ],
    ranks: { "a": 0, "b": 0 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, base_bbox)
}

///|
test "expand_bbox_for_edge_labels keeps self-edge mid labels even on the same rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  edge.set_attr("label", "self")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let label_pos = Some(@edge_spline.point(25.0, 25.0))
  let metrics : LabelExtent? = match
    @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => Some({ width: value.width, height: value.height })
    None => fail("expected mid label metrics")
  }

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [layout_edge(edge, straight_spline(), label_pos~)],
    ranks: { "n": 0 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, expand_bbox_for_label_pos(base_bbox, label_pos, metrics))
}

///|
test "expand_bbox_for_edge_labels raises top for flat-label vnode edges in TB" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_pos = Some(@edge_spline.point(25.0, 25.0))
  let edge_layout = layout_edge(edge, straight_spline(), label_pos~)
  let flat_label_edge_vnodes : Map[String, String] = Map::new()
  flat_label_edge_vnodes[@edge_identity.edge_key(edge)] = "v_flat"
  let ranks : Map[String, Int] = { "a": 0, "b": 0 }
  let flags = classify_flat_edge_label(edge, ranks, flat_label_edge_vnodes)
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let mid_bbox = expand_bbox_for_edge_mid_label(
    base_bbox, edge_layout, flags, false,
  )
  let expected = maybe_raise_flat_edge_vnode_bbox_top(
    mid_bbox,
    edge_layout,
    flags,
    @rankdir.RankDir::TB,
    false,
  )

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks,
    flat_label_edge_vnodes,
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, expected)
  assert_true(output.ury > mid_bbox.ury)
}

///|
test "expand_bbox_for_edge_labels flips endpoint label extent in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("headlabel", "wide-head")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let head_label_pos = Some(@edge_spline.point(25.0, 25.0))
  let edge_layout = layout_edge(edge, straight_spline(), head_label_pos~)
  let metrics : LabelExtent? = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => Some({ width: value.width, height: value.height })
    None => fail("expected head label metrics")
  }

  let tb_output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks: { "a": 0, "b": 1 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })
  let lr_output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks: { "a": 0, "b": 1 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::LR,
  })

  assert_eq(
    tb_output,
    expand_bbox_for_label_pos(
      base_bbox,
      head_label_pos,
      edge_label_extent_for_rankdir(metrics, false),
    ),
  )
  assert_eq(
    lr_output,
    expand_bbox_for_label_pos(
      base_bbox,
      head_label_pos,
      edge_label_extent_for_rankdir(metrics, true),
    ),
  )
  assert_true(tb_output.urx > lr_output.urx)
  assert_true(lr_output.ury > tb_output.ury)
}

///|
test "nudge_label_rect shifts along the lower-overlap axis and rebuilds the rect" {
  let horizontal_pos = @edge_spline.point(10.0, 10.0)
  let horizontal_rect = rect_from_center(horizontal_pos, 4.0, 4.0, 1.0)
  let horizontal = nudge_label_rect(
    horizontal_pos,
    horizontal_rect,
    { llx: 11.0, lly: 8.0, urx: 16.0, ury: 12.0 },
    4.0,
    4.0,
    1.0,
  )
  assert_point_close(horizontal.label_pos, @edge_spline.point(7.0, 10.0))
  assert_eq(
    horizontal.label_rect,
    rect_from_center(horizontal.label_pos, 4.0, 4.0, 1.0),
  )

  let vertical = nudge_label_rect(
    horizontal.label_pos,
    horizontal.label_rect,
    { llx: 6.0, lly: 11.0, urx: 9.0, ury: 16.0 },
    4.0,
    4.0,
    1.0,
  )
  assert_point_close(vertical.label_pos, @edge_spline.point(7.0, 7.0))
  assert_eq(
    vertical.label_rect,
    rect_from_center(vertical.label_pos, 4.0, 4.0, 1.0),
  )
}

///|
test "adjust_edge_label_positions applies sequential nudges and records the final update" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_pos = Some(@edge_spline.point(10.0, 10.0))
  let edge_layout = layout_edge(edge, straight_spline(), label_pos~)

  let adjusted = adjust_edge_label_positions(
    [edge_layout],
    [
      { llx: 11.0, lly: 8.0, urx: 16.0, ury: 12.0 },
      { llx: 6.0, lly: 11.0, urx: 9.0, ury: 16.0 },
    ],
    1.0,
    _ => Some({ width: 4.0, height: 4.0 }),
  )

  let expected = Some(@edge_spline.point(7.0, 7.0))
  assert_eq(adjusted.edges.length(), 1)
  assert_eq(adjusted.edges[0].label_pos, expected)
  assert_eq(adjusted.updates.get(@edge_identity.edge_key(edge)), expected)
}

///|
test "adjust_edge_label_overlaps spreads sibling labels along the rank axis with tail padding" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let edge_1 = graph.edge(tail, graph.node("left"))
  let edge_2 = graph.edge(tail, graph.node("right"))
  let edge_layouts = [
    layout_edge(
      edge_1,
      straight_spline(),
      label_pos=Some(@edge_spline.point(5.0, 10.0)),
    ),
    layout_edge(
      edge_2,
      straight_spline(),
      label_pos=Some(@edge_spline.point(7.0, 20.0)),
    ),
  ]

  let adjusted = adjust_edge_label_overlaps(
    edge_layouts,
    10.0,
    @rankdir.RankDir::TB,
    _ => Some({ width: 6.0, height: 4.0 }),
    _ => Some(@edge_spline.point(0.0, 0.0)),
  )

  assert_eq(adjusted.updates.get(@edge_identity.edge_key(edge_1)), None)
  assert_eq(
    adjusted.updates.get(@edge_identity.edge_key(edge_2)),
    Some(@edge_spline.point(19.0, 20.0)),
  )
  assert_eq(adjusted.edges[0].label_pos, Some(@edge_spline.point(5.0, 10.0)))
  assert_eq(adjusted.edges[1].label_pos, Some(@edge_spline.point(19.0, 20.0)))
}
