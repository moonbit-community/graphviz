// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
fn build_self_edge_base(
  edge : @cgraph.Edge,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  tail_port_side : Int,
  head_port_side : Int,
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  rankdir? : RankDir = RankDir::TB,
) -> EdgeRouteBase {
  let node = edge.tail()
  let name = node.name()
  let pos = @edge_spline.point(0.0, 0.0)
  let size = @node_primitives.node_size_from_points(40.0, 20.0)
  {
    edge,
    parallel_offset: 0.0,
    swap_ends: false,
    orig_tail_name: name,
    orig_head_name: name,
    tail_name: name,
    head_name: name,
    tail_port,
    head_port,
    tail_node: node,
    head_node: node,
    tail_pos: pos,
    head_pos: pos,
    tail_size: size,
    head_size: size,
    mid_label_width_pt: 0.0,
    mid_label_height_pt: 0.0,
    tail_record_path_box: None,
    head_record_path_box: None,
    tail_anchor,
    head_anchor,
    head_port_rect: None,
    tail_port_side,
    head_port_side,
    tail_sameport_group_size: 0,
    head_sameport_group_size: 0,
    tail_clip_center: pos,
    tail_clip_size: size,
    head_clip_center: pos,
    head_clip_size: size,
    tail_clip_enabled: true,
    head_clip_enabled: true,
    tail_clip: tail_anchor,
    head_clip: head_anchor,
    tail_slope: @edge_spline.point(0.0, 0.0),
    head_slope: @edge_spline.point(0.0, 0.0),
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank: 0,
    head_rank: 0,
    is_flat_edge: true,
    is_flat_adjacent: false,
    vnodes: [],
    has_vnodes: false,
    use_pathplan: false,
    route_include_tail: false,
    route_include_head: false,
    arrow_len_override: None,
    is_dotted: false,
    same_outer_cluster: true,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor: tail_anchor,
    out_head_anchor: head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: pos,
    out_head_pos: pos,
    out_tail_size: size,
    out_head_size: size,
    rankdir,
    layout_rankdir: rankdir,
    has_side_anchor: false,
  }
}

///|
test "build_self_edge_routes sends implicit self-edge loops to the right" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  let base = build_self_edge_base(
    edge,
    @edge_spline.point(8.0, 5.0),
    @edge_spline.point(8.0, -5.0),
    0,
    0,
  )
  let rank_y : Map[Int, Double] = { 0: 0.0 }

  let routes = build_self_edge_routes({
    edges: [edge],
    bases: [base],
    nodesep_pt: 12.0,
    rank_y,
    self_edge_label_height_fn: (_edge, _rankdir) => 0.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
  })

  assert_eq(routes.length(), 1)
  let route = routes[0]
  assert_eq(route.label_pos, None)
  assert_eq(route.points[0], @edge_spline.point(8.0, 5.0))
  assert_eq(route.points[6], @edge_spline.point(8.0, -5.0))
  assert_true(route.points[2].x > 0.0)
  assert_true(route.points[3].x > 0.0)
  assert_true(route.points[4].x > 0.0)
}

///|
test "build_self_edge_routes keeps top-port labels above the node" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  let top_port = Some(@cgraph.Port::{
    name: None,
    compass: Some(@cgraph.Compass::N),
  })
  let base = build_self_edge_base(
    edge,
    @edge_spline.point(-6.0, 10.0),
    @edge_spline.point(6.0, 10.0),
    PORT_SIDE_TOP,
    PORT_SIDE_TOP,
    tail_port=top_port,
    head_port=top_port,
  )
  let rank_y : Map[Int, Double] = { 0: 0.0 }

  let routes = build_self_edge_routes({
    edges: [edge],
    bases: [base],
    nodesep_pt: 12.0,
    rank_y,
    self_edge_label_height_fn: (_edge, _rankdir) => 8.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
  })

  assert_eq(routes.length(), 1)
  let route = routes[0]
  match route.label_pos {
    Some(label_pos) => assert_true(label_pos.y > 0.0)
    None => fail("expected self-edge label position")
  }
  assert_true(route.points[2].y > 0.0)
  assert_true(route.points[3].y > 0.0)
  assert_true(route.points[4].y > 0.0)
  assert_close(route.points[0].y, 10.0)
  assert_close(route.points[6].y, 10.0)
}
