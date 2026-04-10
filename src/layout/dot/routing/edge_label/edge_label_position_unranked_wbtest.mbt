// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
