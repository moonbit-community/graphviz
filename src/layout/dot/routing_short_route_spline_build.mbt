fn bottom_single_arrow_line_endpoints(
  prefer_linear_flat_bottom_single_arrow : Bool,
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_clip_size : NodeSize,
  head_clip_size : NodeSize,
) -> (@geom.Point, @geom.Point) {
  if prefer_linear_flat_bottom_single_arrow {
    let tail_bottom = tail_clip_center.y - tail_clip_size.height_pt / 2.0
    let head_bottom = head_clip_center.y - head_clip_size.height_pt / 2.0
    let line_y = min_double(tail_bottom, head_bottom)
    (@edge_spline.point(line_start.x, line_y), @edge_spline.point(line_end.x, line_y))
  } else {
    (line_start, line_end)
  }
}

///|
fn prefer_linear_for_flat_line(
  prefer_linear_flat_invis : Bool,
  flat_no_arrow_candidate : Bool,
  has_flat_detour : Bool,
  prefer_linear_flat_bottom_single_arrow : Bool,
) -> Bool {
  prefer_linear_flat_invis ||
  (flat_no_arrow_candidate && !has_flat_detour) ||
  prefer_linear_flat_bottom_single_arrow
}

///|
fn build_points_spline(
  base : EdgeRouteBase,
  points : Array[@geom.Point],
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  using_pathplan : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  let raw_bezier =
    if using_pathplan {
      @edge_spline.edge_spline_raw_for_points(
        points,
        tail_slope_line,
        head_slope_line,
        force_segmented,
        route_barriers=route_barriers,
      )
    } else {
      []
    }
  let spline =
    @edge_spline.edge_spline_for_points(
      base.edge,
      points,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      tail_slope_line,
      head_slope_line,
      force_segmented,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=base.tail_clip_enabled,
      head_clip_enabled=base.head_clip_enabled,
      tail_port_side=base.tail_port_side,
      head_port_side=base.head_port_side,
      route_barriers=route_barriers,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
      clip_swapped=base.swap_ends,
      arrow_swapped=base.swap_ends,
    )
  { spline, raw_bezier }
}

///|
fn pathplan_line_points_or_endpoints(
  points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
) -> Array[@geom.Point] {
  if points.length() >= 2 { points } else { [line_start, line_end] }
}

///|
fn build_pathplan_points_spline(
  base : EdgeRouteBase,
  pathplan_points : Array[@geom.Point],
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  build_points_spline(
    base,
    pathplan_points,
    tail_slope_line,
    head_slope_line,
    force_segmented,
    true,
    route_barriers,
  )
}

///|
fn build_line_spline(
  base : EdgeRouteBase,
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear : Bool,
) -> @geom.Spline {
  @edge_spline.edge_spline_for_line(
    base.edge,
    line_start,
    line_end,
    base.tail_clip_center,
    base.head_clip_center,
    base.tail_clip_size,
    base.head_clip_size,
    tail_slope_line,
    head_slope_line,
    base.route_include_tail,
    base.route_include_head,
    tail_clip_enabled=tail_clip_enabled,
    head_clip_enabled=head_clip_enabled,
    base.layout_rankdir,
    curve_offset,
    curve_skew,
    arrow_len_override=base.arrow_len_override,
    tail_cluster_bbox=base.tail_cluster_bbox,
    head_cluster_bbox=base.head_cluster_bbox,
    prefer_linear=prefer_linear,
    parallel_offset=base.parallel_offset,
    clip_swapped=base.swap_ends,
    arrow_swapped=base.swap_ends,
  )
}

fn build_short_route_line_or_pathplan_spline(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  pathplan_points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear : Bool,
) -> PointsSplineResult {
  if using_pathplan {
    build_pathplan_points_spline(
      base,
      pathplan_points,
      tail_slope_line,
      head_slope_line,
      force_segmented,
      route_barriers,
    )
  } else {
    {
      spline:
        build_line_spline(
          base,
          line_start,
          line_end,
          tail_slope_line,
          head_slope_line,
          tail_clip_enabled,
          head_clip_enabled,
          curve_offset,
          curve_skew,
          prefer_linear,
        ),
      raw_bezier: [],
    }
  }
}

///|
fn build_flat_detour_spline(
  base : EdgeRouteBase,
  detour : FlatDetourResult,
  using_pathplan : Bool,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> PointsSplineResult {
  let detour_points = detour.points
  let first_right = detour.first_right
  let last_left = detour.last_left
  let detour_y = detour.detour_y
  let vspace = detour.vspace
  let points_spline =
    build_points_spline(
      base,
      detour_points,
      tail_slope_line,
      head_slope_line,
      true,
      using_pathplan,
      route_barriers,
    )
  let raw_bezier = points_spline.raw_bezier
  let mut detour_spline = points_spline.spline
  if detour_spline.points.length() == 10 &&
    (base.layout_rankdir == RankDir::TB || base.layout_rankdir == RankDir::BT) {
    let gap = last_left - first_right
    if gap > 200.0 {
      let points = detour_spline.points.copy()
      points[4] = {
        x: first_right + 0.76,
        y: detour_y + vspace * 0.3535,
      }
      points[5] = {
        x: last_left + 0.25,
        y: detour_y + vspace * 0.4016,
      }
      detour_spline = {
        start: detour_spline.start,
        end: detour_spline.end,
        points,
      }
    }
  }
  { spline: detour_spline, raw_bezier }
}

///|
fn detour_spline_if_any(
  base : EdgeRouteBase,
  needs_record_detour : Bool,
  flat_detour : FlatDetourResult?,
  using_pathplan : Bool,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  nodesep_pt : Double,
  lr_detour_uses_x_axis : Bool,
) -> PointsSplineResult? {
  if needs_record_detour {
    let detour_points =
      record_port_detour_points(
        base.tail_clip_center,
        base.head_clip_center,
        base.tail_clip_size,
        base.head_clip_size,
        base.tail_clip,
        base.head_clip,
        nodesep_pt,
        base.layout_rankdir,
        lr_detour_uses_x_axis,
      )
    Some(
      build_points_spline(
        base,
        detour_points,
        tail_slope_line,
        head_slope_line,
        true,
        using_pathplan,
        route_barriers,
      ),
    )
  } else {
    match flat_detour {
      Some(detour) =>
        Some(
          build_flat_detour_spline(
            base,
            detour,
            using_pathplan,
            tail_slope_line,
            head_slope_line,
            route_barriers,
          ),
        )
      None => None
    }
  }
}
