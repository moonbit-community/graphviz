// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn explicit_compass_port(compass : @cgraph.Compass) -> @cgraph.Port? {
  Some({ name: None, compass: Some(compass) })
}

///|
fn short_route_assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn short_route_assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  short_route_assert_close(actual.x, expected.x, eps~)
  short_route_assert_close(actual.y, expected.y, eps~)
}

///|
fn short_route_assert_points_close(
  actual : Array[@geom.Point],
  expected : Array[@geom.Point],
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    short_route_assert_point_close(actual[i], expected[i], eps~)
  }
}

///|
fn short_route_test_base(
  edge : @cgraph.Edge,
  tail_anchor? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_anchor? : @geom.Point = @edge_spline.point(10.0, 0.0),
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  tail_port_side? : Int = 0,
  head_port_side? : Int = 0,
  route_include_tail? : Bool = false,
  route_include_head? : Bool = false,
  tail_slope? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_slope? : @geom.Point = @edge_spline.point(0.0, 0.0),
) -> EdgeRouteBase {
  let size = @node_primitives.node_size_from_points(10.0, 10.0)
  {
    edge,
    parallel_offset: 0.0,
    swap_ends: false,
    orig_tail_name: edge.tail().name(),
    orig_head_name: edge.head().name(),
    tail_name: edge.tail().name(),
    head_name: edge.head().name(),
    tail_port,
    head_port,
    tail_node: edge.tail(),
    head_node: edge.head(),
    tail_pos: tail_anchor,
    head_pos: head_anchor,
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
    tail_clip_center: tail_anchor,
    tail_clip_size: size,
    head_clip_center: head_anchor,
    head_clip_size: size,
    tail_clip_enabled: false,
    head_clip_enabled: false,
    tail_clip: tail_anchor,
    head_clip: head_anchor,
    tail_slope,
    head_slope,
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank: 0,
    head_rank: 1,
    is_flat_edge: true,
    is_flat_adjacent: false,
    vnodes: [],
    has_vnodes: false,
    use_pathplan: false,
    route_include_tail,
    route_include_head,
    arrow_len_override: None,
    is_dotted: false,
    same_outer_cluster: true,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor: tail_anchor,
    out_head_anchor: head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: tail_anchor,
    out_head_pos: head_anchor,
    out_tail_size: size,
    out_head_size: size,
    rankdir: RankDir::TB,
    layout_rankdir: RankDir::TB,
    has_side_anchor: false,
  }
}

///|
fn short_route_test_context(
  base : EdgeRouteBase,
  has_explicit_port : Bool,
) -> ShortRouteBuildContext {
  short_route_build_context({
    base,
    positions: Map::new(),
    sizes: Map::new(),
    ranks: Map::new(),
    rank_y: Map::new(),
    rank_ht1: Map::new(),
    rank_ht2: Map::new(),
    ranksep_pt: 12.0,
    route_barriers: [],
    using_pathplan: false,
    has_explicit_port,
    label_width_pt: 0.0,
    nodesep_pt: 12.0,
    force_segmented: false,
    curve_offset: 0.0,
    curve_skew: 1.0,
  })
}
