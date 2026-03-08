///|
fn route_dynamic_anchor(
  anchor : @geom.Point?,
  side? : Int = 0,
  is_dynamic? : Bool = false,
) -> RouteDynamicPortAnchor {
  { anchor, side, is_dynamic }
}

///|
test "clip_point_for_route_endpoint prefers cluster bbox over other clip sources" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("shape", "box")
  let clipped = clip_point_for_route_endpoint({
    anchor: @edge_spline.point(0.0, 0.0),
    opposite_anchor: @edge_spline.point(10.0, 0.0),
    cluster_bbox: Some({ llx: 4.0, lly: -1.0, urx: 6.0, ury: 1.0 }),
    dynamic_anchor: route_dynamic_anchor(Some(@edge_spline.point(9.0, 9.0))),
    compass_clip: Some(@edge_spline.point(8.0, 8.0)),
    node,
    clip_center: @edge_spline.point(0.0, 0.0),
    clip_size: @node_primitives.node_size_from_points(20.0, 20.0),
    clip_target: @edge_spline.point(12.0, 0.0),
  })

  assert_eq(clipped, @edge_spline.point(4.0, 0.0))
}

///|
test "clip_point_for_route_endpoint prefers dynamic anchor then compass clip" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("shape", "box")

  let dynamic_clipped = clip_point_for_route_endpoint({
    anchor: @edge_spline.point(0.0, 0.0),
    opposite_anchor: @edge_spline.point(10.0, 0.0),
    cluster_bbox: None,
    dynamic_anchor: route_dynamic_anchor(Some(@edge_spline.point(9.0, 9.0))),
    compass_clip: Some(@edge_spline.point(8.0, 8.0)),
    node,
    clip_center: @edge_spline.point(0.0, 0.0),
    clip_size: @node_primitives.node_size_from_points(20.0, 20.0),
    clip_target: @edge_spline.point(12.0, 0.0),
  })
  assert_eq(dynamic_clipped, @edge_spline.point(9.0, 9.0))

  let compass_clipped = clip_point_for_route_endpoint({
    anchor: @edge_spline.point(0.0, 0.0),
    opposite_anchor: @edge_spline.point(10.0, 0.0),
    cluster_bbox: None,
    dynamic_anchor: route_dynamic_anchor(None),
    compass_clip: Some(@edge_spline.point(8.0, 8.0)),
    node,
    clip_center: @edge_spline.point(0.0, 0.0),
    clip_size: @node_primitives.node_size_from_points(20.0, 20.0),
    clip_target: @edge_spline.point(12.0, 0.0),
  })
  assert_eq(compass_clipped, @edge_spline.point(8.0, 8.0))
}

///|
test "clustered_edge_arrow_len_override clamps short cluster spans" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)
  edge.set_attr("arrowtail", "crow")
  edge.set_attr("arrowhead", "box")
  edge.set_attr("arrowsize", "1.5")
  edge.set_attr("penwidth", "2.0")

  let override_len = clustered_edge_arrow_len_override({
    edge,
    include_tail: true,
    include_head: true,
    tail_cluster_bbox: Some({ llx: 0.0, lly: 0.0, urx: 1.0, ury: 1.0 }),
    head_cluster_bbox: None,
    tail_clip: @edge_spline.point(0.0, 0.0),
    head_clip: @edge_spline.point(1.0, 0.0),
  })
  assert_eq(override_len, Some(0.25))

  let no_cluster_override = clustered_edge_arrow_len_override({
    edge,
    include_tail: true,
    include_head: true,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_clip: @edge_spline.point(0.0, 0.0),
    head_clip: @edge_spline.point(1.0, 0.0),
  })
  assert_eq(no_cluster_override, None)
}

///|
test "should_apply_flat_bottom_dirboth_x_nudge only enables for bottom dirboth flats" {
  let bottom_port = Some(@cgraph.Port::{
    name: None,
    compass: Some(@cgraph.Compass::S),
  })
  let dynamic_none = route_dynamic_anchor(None)
  let enabled = should_apply_flat_bottom_dirboth_x_nudge({
    dir: @edge_semantics.EdgeDir::Both,
    is_flat_edge: true,
    has_vnodes: false,
    mid_label_width_pt: 0.0,
    tail_sameport_anchor: None,
    head_sameport_anchor: None,
    tail_dynamic_anchor: dynamic_none,
    head_dynamic_anchor: dynamic_none,
    compass_tail_on_non_record: true,
    compass_head_on_non_record: true,
    tail_port: bottom_port,
    head_port: bottom_port,
    tail_port_side: PORT_SIDE_BOTTOM,
    head_port_side: PORT_SIDE_BOTTOM,
    layout_rankdir: RankDir::TB,
  })
  assert_true(enabled)

  let disabled_for_top = should_apply_flat_bottom_dirboth_x_nudge({
    dir: @edge_semantics.EdgeDir::Both,
    is_flat_edge: true,
    has_vnodes: false,
    mid_label_width_pt: 0.0,
    tail_sameport_anchor: None,
    head_sameport_anchor: None,
    tail_dynamic_anchor: dynamic_none,
    head_dynamic_anchor: dynamic_none,
    compass_tail_on_non_record: true,
    compass_head_on_non_record: true,
    tail_port: bottom_port,
    head_port: bottom_port,
    tail_port_side: PORT_SIDE_TOP,
    head_port_side: PORT_SIDE_TOP,
    layout_rankdir: RankDir::TB,
  })
  assert_false(disabled_for_top)
}
