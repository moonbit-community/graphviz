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
fn build_curve_base(
  edge : @cgraph.Edge,
  tail_anchor? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_anchor? : @geom.Point = @edge_spline.point(10.0, 0.0),
  head_port? : @cgraph.Port? = None,
  layout_rankdir? : RankDir = RankDir::TB,
  orig_head_name? : String = edge.head().name(),
) -> EdgeRouteBase {
  let zero = @edge_spline.point(0.0, 0.0)
  let size = @node_primitives.node_size_from_points(10.0, 10.0)
  {
    edge,
    parallel_offset: 0.0,
    swap_ends: false,
    orig_tail_name: edge.tail().name(),
    orig_head_name,
    tail_name: edge.tail().name(),
    head_name: edge.head().name(),
    tail_port: None,
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
    tail_port_side: 0,
    head_port_side: 0,
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
    tail_slope: zero,
    head_slope: zero,
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank: 0,
    head_rank: 1,
    is_flat_edge: false,
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
    out_tail_pos: tail_anchor,
    out_head_pos: head_anchor,
    out_tail_size: size,
    out_head_size: size,
    rankdir: layout_rankdir,
    layout_rankdir,
    has_side_anchor: false,
  }
}

///|
test "compute_curve_offset keeps defaults when tuning is disabled or the metric key is absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let head = graph.node("head")
  head.set_attr("shape", "record")
  let edge = graph.edge(graph.node("tail"), head)
  let base = build_curve_base(edge, orig_head_name="head")
  let metrics : HeadPortMetrics = {
    head_port_counts: { "head": 3 },
    head_port_min_dist: { "head": 0.0 },
    head_port_max_dist: { "head": 10.0 },
  }

  let disabled = compute_curve_offset({
    edge,
    base,
    head_port_metrics: metrics,
    label_width_pt: 8.0,
    nodesep_pt: 12.0,
    enable_complex_tuning: false,
  })
  let missing_key = compute_curve_offset({
    edge,
    base: build_curve_base(edge, orig_head_name="other"),
    head_port_metrics: {
      head_port_counts: Map::new(),
      head_port_min_dist: Map::new(),
      head_port_max_dist: Map::new(),
    },
    label_width_pt: 8.0,
    nodesep_pt: 12.0,
    enable_complex_tuning: true,
  })

  assert_eq(disabled.curve_offset, 0.0)
  assert_eq(disabled.curve_skew, 1.0)
  assert_eq(missing_key.curve_offset, 0.0)
  assert_eq(missing_key.curve_skew, 1.0)
}

///|
test "compute_curve_offset uses explicit head port metrics and halves skew for backward TB edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("tail"), graph.node("head"), head_port={
    name: Some("p"),
    compass: Some(@cgraph.Compass::E),
  })
  let base = build_curve_base(
    edge,
    tail_anchor=@edge_spline.point(10.0, 0.0),
    head_anchor=@edge_spline.point(-10.0, 0.0),
    head_port=Some({ name: Some("p"), compass: Some(@cgraph.Compass::E) }),
    layout_rankdir=RankDir::TB,
  )

  let params = compute_curve_offset({
    edge,
    base,
    head_port_metrics: {
      head_port_counts: { "head:p:e": 3 },
      head_port_min_dist: { "head:p:e": 10.0 },
      head_port_max_dist: { "head:p:e": 30.0 },
    },
    label_width_pt: 8.0,
    nodesep_pt: 10.0,
    enable_complex_tuning: true,
  })

  assert_close(params.curve_offset, 1.5)
  assert_eq(params.curve_skew, 0.5)
}

///|
test "compute_curve_offset falls back to record-head name when no explicit head port exists" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let head = graph.node("record_head")
  head.set_attr("shape", "record")
  let edge = graph.edge(graph.node("tail"), head)
  let base = build_curve_base(
    edge,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(3.0, 4.0),
    orig_head_name="record_head",
  )

  let params = compute_curve_offset({
    edge,
    base,
    head_port_metrics: {
      head_port_counts: { "record_head": 2 },
      head_port_min_dist: { "record_head": 0.0 },
      head_port_max_dist: { "record_head": 10.0 },
    },
    label_width_pt: 0.0,
    nodesep_pt: 8.0,
    enable_complex_tuning: true,
  })

  assert_close(params.curve_offset, 0.6)
  assert_eq(params.curve_skew, 1.0)
}
