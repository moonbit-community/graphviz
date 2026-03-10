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
