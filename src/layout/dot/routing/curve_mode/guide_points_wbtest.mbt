// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "edge_polyline_points expands flat labeled vnode points and preserves left-right order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1"]
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v1"] = @edge_spline.point(10.0, 0.0)

  let points = edge_polyline_points({
    edge,
    tail_name: "a",
    head_name: "b",
    tail_port: None,
    head_port: None,
    tail_anchor: @edge_spline.point(0.0, 0.0),
    head_anchor: @edge_spline.point(20.0, 0.0),
    ranks: { "a": 0, "b": 0 },
    edge_vnodes,
    vnode_ranks: Map::new(),
    vnode_positions,
    rank_y: Map::new(),
    rank_ht1: Map::new(),
    nodesep_pt: 12.0,
    label_width_pt: 4.0,
    label_height_pt: Some(8.0),
    dotted_weight: 1.0,
    use_cluster_tuning: false,
    split_label: false,
    same_local_cluster: true,
    default_vnode_weight: DEFAULT_VNODE_WEIGHT,
  })

  assert_eq(points, [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(8.0, -1.0),
    @edge_spline.point(12.0, -1.0),
    @edge_spline.point(20.0, 0.0),
  ])
}

///|
test "edge_polyline_points applies cluster-tuned interpolation on non-flat vnode ranks" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1"]
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v1"] = @edge_spline.point(8.0, 40.0)

  let rank_y : Map[Int, Double] = Map::new()
  rank_y[1] = 50.0
  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[1] = 3.0

  let points = edge_polyline_points({
    edge,
    tail_name: "a",
    head_name: "b",
    tail_port: None,
    head_port: None,
    tail_anchor: @edge_spline.point(0.0, 0.0),
    head_anchor: @edge_spline.point(20.0, 100.0),
    ranks: { "a": 0, "b": 2 },
    edge_vnodes,
    vnode_ranks,
    vnode_positions,
    rank_y,
    rank_ht1,
    nodesep_pt: 12.0,
    label_width_pt: 6.0,
    label_height_pt: None,
    dotted_weight: 1.0,
    use_cluster_tuning: true,
    split_label: false,
    same_local_cluster: false,
    default_vnode_weight: DEFAULT_VNODE_WEIGHT,
  })

  assert_eq(points, [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(6.2, 53.0),
    @edge_spline.point(20.0, 100.0),
  ])
}
