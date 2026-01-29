///|
fn point(x : Double, y : Double) -> @geom.Point {
  @edge_spline.point(x, y)
}

///|
fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  @edge_spline.point_add(a, b)
}

///|
fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  @edge_spline.point_sub(a, b)
}

///|
fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  @edge_spline.point_scale(a, s)
}

///|
fn point_dist2(a : @geom.Point, b : @geom.Point) -> Double {
  @edge_spline.point_dist2(a, b)
}

///|
fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  @edge_spline.point_lerp(a, b, t)
}

///|
fn point_dist(a : @geom.Point, b : @geom.Point) -> Double {
  @edge_spline.point_dist(a, b)
}

///|
fn segment_length(a : @geom.Point, b : @geom.Point) -> Double {
  @edge_spline.segment_length(a, b)
}

///|
fn polyline_length(points : Array[@geom.Point]) -> Double {
  @edge_spline.polyline_length(points)
}

///|
fn arrow_length_for_edge(edge : @cgraph.Edge) -> Double {
  @edge_spline.arrow_length_for_edge(edge)
}

///|
fn port_side_rect(node_pos : @geom.Point, node_size : NodeSize) -> @geom.Rect {
  @edge_spline.port_side_rect(node_pos, node_size)
}

///|
fn port_side_count(
  port_rect : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  @edge_spline.port_side_count(port_rect, node_pos, node_size)
}

///|
fn endpoint_slope_for_anchor(
  port : @cgraph.Port?,
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
  rankdir : RankDir,
  tail : Bool,
  port_rect : @geom.Rect?,
) -> @geom.Point {
  @edge_spline.endpoint_slope_for_anchor(
    port,
    anchor,
    node_pos,
    node_size,
    target,
    rankdir,
    tail,
    port_rect,
  )
}

///|
fn edge_spline_for_polyline(
  edge : @cgraph.Edge,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  orthogonal : Bool,
  include_tail : Bool,
  include_head : Bool,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_polyline(
    edge,
    tail_clip_center,
    head_clip_center,
    tail_anchor_size,
    head_anchor_size,
    tail_clip,
    head_clip,
    rankdir,
    orthogonal,
    include_tail,
    include_head,
    arrow_len_override=arrow_len_override,
    tail_cluster_bbox=tail_cluster_bbox,
    head_cluster_bbox=head_cluster_bbox,
  )
}

///|
fn edge_spline_for_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  force_segmented : Bool,
  include_tail : Bool,
  include_head : Bool,
  route_barriers? : Array[(@geom.Point, @geom.Point)] = [],
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_points(
    edge,
    points,
    tail_clip_center,
    head_clip_center,
    tail_anchor_size,
    head_anchor_size,
    tail_slope,
    head_slope,
    force_segmented,
    include_tail,
    include_head,
    route_barriers=route_barriers,
    arrow_len_override=arrow_len_override,
    tail_cluster_bbox=tail_cluster_bbox,
    head_cluster_bbox=head_cluster_bbox,
  )
}

///|
fn edge_spline_for_line(
  edge : @cgraph.Edge,
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  include_tail : Bool,
  include_head : Bool,
  rankdir : RankDir,
  curve_offset : Double,
  curve_skew : Double,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_line(
    edge,
    tail_center,
    head_center,
    tail_clip_center,
    head_clip_center,
    tail_anchor_size,
    head_anchor_size,
    tail_slope,
    head_slope,
    include_tail,
    include_head,
    rankdir,
    curve_offset,
    curve_skew,
    arrow_len_override=arrow_len_override,
    tail_cluster_bbox=tail_cluster_bbox,
    head_cluster_bbox=head_cluster_bbox,
  )
}
