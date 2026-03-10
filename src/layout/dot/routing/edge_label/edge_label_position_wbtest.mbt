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
