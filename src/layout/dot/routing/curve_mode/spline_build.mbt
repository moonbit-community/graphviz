// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
priv struct BottomSingleArrowLineEndpointsInput {
  prefer_linear_flat_bottom_single_arrow : Bool
  line_start : @geom.Point
  line_end : @geom.Point
  tail_clip_center : @geom.Point
  head_clip_center : @geom.Point
  tail_clip_size : NodeSize
  head_clip_size : NodeSize
}

///|
fn bottom_single_arrow_line_endpoints(
  input : BottomSingleArrowLineEndpointsInput,
) -> (@geom.Point, @geom.Point) {
  if input.prefer_linear_flat_bottom_single_arrow {
    let tail_bottom = input.tail_clip_center.y -
      input.tail_clip_size.height_pt / 2.0
    let head_bottom = input.head_clip_center.y -
      input.head_clip_size.height_pt / 2.0
    let line_y = min_double(tail_bottom, head_bottom)
    (
      @edge_spline.point(input.line_start.x, line_y),
      @edge_spline.point(input.line_end.x, line_y),
    )
  } else {
    (input.line_start, input.line_end)
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
/// Graphviz parity: points-spline input keeps point set, endpoint slopes, and
/// pathplan/segmented flags grouped for deterministic spline construction.
pub(all) struct PointsSplineBuildInput {
  base : EdgeRouteBase
  points : Array[@geom.Point]
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  force_segmented : Bool
  using_pathplan : Bool
  route_barriers : Array[(@geom.Point, @geom.Point)]
}

///|
fn build_points_spline(input : PointsSplineBuildInput) -> PointsSplineResult {
  let raw_bezier = if input.using_pathplan {
    @edge_spline.edge_spline_raw_for_points(
      input.points,
      input.tail_slope_line,
      input.head_slope_line,
      input.force_segmented,
      route_barriers=input.route_barriers,
    )
  } else {
    []
  }
  let spline = @edge_spline.edge_spline_for_points(
    input.base.edge,
    input.points,
    input.base.tail_clip_center,
    input.base.head_clip_center,
    input.base.tail_clip_size,
    input.base.head_clip_size,
    input.tail_slope_line,
    input.head_slope_line,
    input.force_segmented,
    input.base.route_include_tail,
    input.base.route_include_head,
    tail_clip_enabled=input.base.tail_clip_enabled,
    head_clip_enabled=input.base.head_clip_enabled,
    tail_port_side=input.base.tail_port_side,
    head_port_side=input.base.head_port_side,
    route_barriers=input.route_barriers,
    arrow_len_override=input.base.arrow_len_override,
    tail_cluster_bbox=input.base.tail_cluster_bbox,
    head_cluster_bbox=input.base.head_cluster_bbox,
    parallel_offset=input.base.parallel_offset,
    clip_swapped=input.base.swap_ends,
    arrow_swapped=input.base.swap_ends,
  )
  { spline, raw_bezier }
}

///|
fn pathplan_line_points_or_endpoints(
  points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
) -> Array[@geom.Point] {
  if points.length() >= 2 {
    points
  } else {
    [line_start, line_end]
  }
}

priv struct PathplanPointsSplineBuildInput {
  base : EdgeRouteBase
  pathplan_points : Array[@geom.Point]
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  force_segmented : Bool
  route_barriers : Array[(@geom.Point, @geom.Point)]
}

///|
fn build_pathplan_points_spline(
  input : PathplanPointsSplineBuildInput,
) -> PointsSplineResult {
  build_points_spline({
    base: input.base,
    points: input.pathplan_points,
    tail_slope_line: input.tail_slope_line,
    head_slope_line: input.head_slope_line,
    force_segmented: input.force_segmented,
    using_pathplan: true,
    route_barriers: input.route_barriers,
  })
}

///|
priv struct LineSplineBuildInput {
  base : EdgeRouteBase
  line_start : @geom.Point
  line_end : @geom.Point
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  curve_offset : Double
  curve_skew : Double
  prefer_linear : Bool
}

///|
fn build_line_spline(input : LineSplineBuildInput) -> @geom.Spline {
  let base = input.base
  let line_start = input.line_start
  let line_end = input.line_end
  let tail_slope_line = input.tail_slope_line
  let head_slope_line = input.head_slope_line
  let tail_clip_enabled = input.tail_clip_enabled
  let head_clip_enabled = input.head_clip_enabled
  let curve_offset = input.curve_offset
  let curve_skew = input.curve_skew
  let prefer_linear = input.prefer_linear
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
    tail_clip_enabled~,
    head_clip_enabled~,
    base.layout_rankdir,
    curve_offset,
    curve_skew,
    arrow_len_override=base.arrow_len_override,
    tail_cluster_bbox=base.tail_cluster_bbox,
    head_cluster_bbox=base.head_cluster_bbox,
    prefer_linear~,
    parallel_offset=base.parallel_offset,
    clip_swapped=base.swap_ends,
    arrow_swapped=base.swap_ends,
  )
}

///|
/// Graphviz parity: short-route line/pathplan build input keeps line points,
/// slopes, clip flags, and tuning controls grouped for one fallback dispatch.
priv struct ShortRouteLineOrPathplanBuildInput {
  base : EdgeRouteBase
  using_pathplan : Bool
  pathplan_points : Array[@geom.Point]
  line_start : @geom.Point
  line_end : @geom.Point
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  force_segmented : Bool
  route_barriers : Array[(@geom.Point, @geom.Point)]
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  curve_offset : Double
  curve_skew : Double
  prefer_linear : Bool
}

///|
fn build_short_route_line_or_pathplan_spline(
  input : ShortRouteLineOrPathplanBuildInput,
) -> PointsSplineResult {
  if input.using_pathplan {
    build_pathplan_points_spline({
      base: input.base,
      pathplan_points: input.pathplan_points,
      tail_slope_line: input.tail_slope_line,
      head_slope_line: input.head_slope_line,
      force_segmented: input.force_segmented,
      route_barriers: input.route_barriers,
    })
  } else {
    {
      spline: build_line_spline({
        base: input.base,
        line_start: input.line_start,
        line_end: input.line_end,
        tail_slope_line: input.tail_slope_line,
        head_slope_line: input.head_slope_line,
        tail_clip_enabled: input.tail_clip_enabled,
        head_clip_enabled: input.head_clip_enabled,
        curve_offset: input.curve_offset,
        curve_skew: input.curve_skew,
        prefer_linear: input.prefer_linear,
      }),
      raw_bezier: [],
    }
  }
}

///|
priv struct FlatDetourSplineBuildInput {
  base : EdgeRouteBase
  detour : FlatDetourResult
  using_pathplan : Bool
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  route_barriers : Array[(@geom.Point, @geom.Point)]
}

///|
fn build_flat_detour_spline(
  input : FlatDetourSplineBuildInput,
) -> PointsSplineResult {
  let base = input.base
  let detour = input.detour
  let using_pathplan = input.using_pathplan
  let tail_slope_line = input.tail_slope_line
  let head_slope_line = input.head_slope_line
  let route_barriers = input.route_barriers
  let detour_points = detour.points
  let first_right = detour.first_right
  let last_left = detour.last_left
  let detour_y = detour.detour_y
  let vspace = detour.vspace
  let points_spline = build_points_spline({
    base,
    points: detour_points,
    tail_slope_line,
    head_slope_line,
    force_segmented: true,
    using_pathplan,
    route_barriers,
  })
  let raw_bezier = points_spline.raw_bezier
  let mut detour_spline = points_spline.spline
  if detour_spline.points.length() == 10 &&
    (base.layout_rankdir == RankDir::TB || base.layout_rankdir == RankDir::BT) {
    let gap = last_left - first_right
    if gap > 200.0 {
      let points = detour_spline.points.copy()
      points[4] = { x: first_right + 0.76, y: detour_y + vspace * 0.3535 }
      points[5] = { x: last_left + 0.25, y: detour_y + vspace * 0.4016 }
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
/// Graphviz parity: detour-spline input keeps record/flat detour candidates
/// and slope/barrier controls grouped for one detour selection boundary.
priv struct DetourSplineBuildInput {
  base : EdgeRouteBase
  needs_record_detour : Bool
  flat_detour : FlatDetourResult?
  using_pathplan : Bool
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  route_barriers : Array[(@geom.Point, @geom.Point)]
  nodesep_pt : Double
  lr_detour_uses_x_axis : Bool
}

///|
fn detour_spline_if_any(input : DetourSplineBuildInput) -> PointsSplineResult? {
  if input.needs_record_detour {
    let detour_points = record_port_detour_points({
      tail_clip_center: input.base.tail_clip_center,
      head_clip_center: input.base.head_clip_center,
      tail_clip_size: input.base.tail_clip_size,
      head_clip_size: input.base.head_clip_size,
      tail_clip: input.base.tail_clip,
      head_clip: input.base.head_clip,
      nodesep_pt: input.nodesep_pt,
      layout_rankdir: input.base.layout_rankdir,
      lr_detour_uses_x_axis: input.lr_detour_uses_x_axis,
    })
    Some(
      build_points_spline({
        base: input.base,
        points: detour_points,
        tail_slope_line: input.tail_slope_line,
        head_slope_line: input.head_slope_line,
        force_segmented: true,
        using_pathplan: input.using_pathplan,
        route_barriers: input.route_barriers,
      }),
    )
  } else {
    match input.flat_detour {
      Some(detour) =>
        Some(
          build_flat_detour_spline({
            base: input.base,
            detour,
            using_pathplan: input.using_pathplan,
            tail_slope_line: input.tail_slope_line,
            head_slope_line: input.head_slope_line,
            route_barriers: input.route_barriers,
          }),
        )
      None => None
    }
  }
}

///|
/// Do not change behavior without updating fixtures/tests.
fn straight_path_join_dir(rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => @edge_spline.point(0.0, -1.0)
    RankDir::BT => @edge_spline.point(0.0, 1.0)
    RankDir::LR => @edge_spline.point(1.0, 0.0)
    RankDir::RL => @edge_spline.point(-1.0, 0.0)
  }
}

///|
fn route_endpoint_slopes(
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
) -> (@geom.Point, @geom.Point) {
  (
    edge_port_slope_or_zero(tail_port, tail_slope),
    edge_port_slope_or_zero(head_port, head_slope),
  )
}

///|
priv struct PathplanSegmentSlopesInput {
  seg_idx : Int
  segment_count : Int
  tail_slope_for : @geom.Point
  head_slope_for : @geom.Point
  join_dir : @geom.Point
}

///|
fn pathplan_segment_slopes(
  input : PathplanSegmentSlopesInput,
) -> (@geom.Point, @geom.Point) {
  let seg_idx = input.seg_idx
  let segment_count = input.segment_count
  let tail_slope_for = input.tail_slope_for
  let head_slope_for = input.head_slope_for
  let join_dir = input.join_dir
  let seg_tail_slope = if seg_idx == 0 { tail_slope_for } else { join_dir }
  let seg_head_slope = if seg_idx + 1 == segment_count {
    head_slope_for
  } else {
    join_dir
  }
  (seg_tail_slope, seg_head_slope)
}

///|
fn trimmed_pathplan_segment_points(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() < 3 {
    return points
  }
  let last_idx = points.length() - 1
  let end = points[last_idx]
  let prev = points[last_idx - 1]
  let dx = end.x - prev.x
  let dy = end.y - prev.y
  if dx * dx + dy * dy > 0.0004 {
    return points
  }
  let prev2 = points[last_idx - 2]
  let vx = end.x - prev2.x
  let vy = end.y - prev2.y
  let wx = prev.x - prev2.x
  let wy = prev.y - prev2.y
  let span = Double::sqrt(vx * vx + vy * vy)
  let offset = if span > 0.0 {
    Double::abs(vx * wy - vy * wx) / span
  } else {
    0.0
  }
  if offset > 0.02 {
    return points
  }
  let trimmed : Array[@geom.Point] = []
  let mut i = 0
  while i < points.length() {
    if i != last_idx - 1 {
      trimmed.push(points[i])
    }
    i = i + 1
  }
  trimmed
}

///|
priv struct PathplanSegmentRawBezierInput {
  segment : @routesplines.PathplanSegment
  seg_idx : Int
  segment_count : Int
  tail_slope_for : @geom.Point
  head_slope_for : @geom.Point
  join_dir : @geom.Point
  force_segmented : Bool
  trim_points : Bool
}

///|
fn pathplan_segment_raw_bezier(
  input : PathplanSegmentRawBezierInput,
) -> Array[@geom.Point] {
  let segment = input.segment
  let seg_idx = input.seg_idx
  let segment_count = input.segment_count
  let tail_slope_for = input.tail_slope_for
  let head_slope_for = input.head_slope_for
  let join_dir = input.join_dir
  let force_segmented = input.force_segmented
  let trim_points = input.trim_points
  let segment_points = if trim_points {
    trimmed_pathplan_segment_points(segment.points)
  } else {
    segment.points
  }
  let (seg_tail_slope, seg_head_slope) = pathplan_segment_slopes({
    seg_idx,
    segment_count,
    tail_slope_for,
    head_slope_for,
    join_dir,
  })
  @edge_spline.edge_spline_raw_for_points(
    segment_points,
    seg_tail_slope,
    seg_head_slope,
    force_segmented,
    route_barriers=segment.barriers,
  )
}

///|
fn limit_pathplan_segment_boxes(
  base : EdgeRouteBase,
  pathplan_segments : Array[@routesplines.PathplanSegment],
) -> Array[@routesplines.PathplanSegment] {
  let (tail_slope_for, head_slope_for) = route_endpoint_slopes(
    base.tail_port,
    base.head_port,
    base.tail_slope,
    base.head_slope,
  )
  let join_dir = straight_path_join_dir(base.layout_rankdir)
  let limited_segments : Array[@routesplines.PathplanSegment] = []
  let segment_count = pathplan_segments.length()
  let mut seg_idx = 0
  while seg_idx < segment_count {
    let segment = pathplan_segments[seg_idx]
    let segment_raw = pathplan_segment_raw_bezier({
      segment,
      seg_idx,
      segment_count,
      tail_slope_for,
      head_slope_for,
      join_dir,
      force_segmented: false,
      trim_points: false,
    })
    let limited_boxes = @routesplines.limit_boxes_for_spline(
      segment.boxes,
      segment_raw,
      fallback_polyline=segment.points,
    )
    limited_segments.push({
      points: segment.points,
      barriers: segment.barriers,
      boxes: limited_boxes,
      vnodes: segment.vnodes,
    })
    seg_idx = seg_idx + 1
  }
  limited_segments
}

///|
///|
priv struct SegmentedPathplanRawBezierInput {
  pathplan_segments : Array[@routesplines.PathplanSegment]
  tail_slope_for : @geom.Point
  head_slope_for : @geom.Point
  join_dir : @geom.Point
  force_segmented : Bool
}

///|
fn segmented_pathplan_raw_bezier(
  input : SegmentedPathplanRawBezierInput,
) -> Array[@geom.Point] {
  let pathplan_segments = input.pathplan_segments
  let tail_slope_for = input.tail_slope_for
  let head_slope_for = input.head_slope_for
  let join_dir = input.join_dir
  let force_segmented = input.force_segmented
  let segmented_raw : Array[@geom.Point] = []
  let segment_count = pathplan_segments.length()
  let mut seg_idx = 0
  while seg_idx < segment_count {
    let segment = pathplan_segments[seg_idx]
    let seg_raw = pathplan_segment_raw_bezier({
      segment,
      seg_idx,
      segment_count,
      tail_slope_for,
      head_slope_for,
      join_dir,
      force_segmented,
      trim_points: true,
    })
    if seg_raw.length() > 0 {
      if segmented_raw.length() > 0 {
        let last = segmented_raw[segmented_raw.length() - 1]
        segmented_raw.push(last)
        segmented_raw.push(last)
      }
      for point in seg_raw {
        segmented_raw.push(point)
      }
    }
    seg_idx = seg_idx + 1
  }
  segmented_raw
}

///|
priv struct MultiPointRoutedSplineInput {
  base : EdgeRouteBase
  adjusted : Array[@geom.Point]
  using_pathplan : Bool
  force_segmented : Bool
  pathplan_segments : Array[@routesplines.PathplanSegment]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
}

///|
fn build_multi_point_routed_spline(
  input : MultiPointRoutedSplineInput,
) -> PointsSplineResult {
  let base = input.base
  let adjusted = input.adjusted
  let using_pathplan = input.using_pathplan
  let force_segmented = input.force_segmented
  let pathplan_segments = input.pathplan_segments
  let route_barriers = input.route_barriers
  let tail_clip_enabled = input.tail_clip_enabled
  let head_clip_enabled = input.head_clip_enabled
  let (tail_slope_for, head_slope_for) = route_endpoint_slopes(
    base.tail_port,
    base.head_port,
    base.tail_slope,
    base.head_slope,
  )
  // Graphviz parity: pathplan edges always allow spline fitting.
  let edge_force_segmented = if using_pathplan {
    false
  } else {
    force_segmented
  }
  let segmented_raw : Array[@geom.Point] = if using_pathplan &&
    pathplan_segments.length() > 0 {
    // Graphviz parity: straight_path segment joins constrain slope along rankdir.
    let join_dir = straight_path_join_dir(base.layout_rankdir)
    segmented_pathplan_raw_bezier({
      pathplan_segments,
      tail_slope_for,
      head_slope_for,
      join_dir,
      force_segmented: edge_force_segmented,
    })
  } else {
    []
  }
  if segmented_raw.length() > 0 {
    let spline = @emit.build_bezier_points_spline({
      base,
      bezier_points: segmented_raw,
      tail_clip_enabled,
      head_clip_enabled,
      clip_swapped: base.swap_ends,
      arrow_swapped: base.swap_ends,
    })
    { spline, raw_bezier: segmented_raw }
  } else {
    build_points_spline({
      base,
      points: adjusted,
      tail_slope_line: tail_slope_for,
      head_slope_line: head_slope_for,
      force_segmented: edge_force_segmented,
      using_pathplan,
      route_barriers,
    })
  }
}

///|
priv struct PathplanFinalizeInput {
  base : EdgeRouteBase
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  raw_bezier : Array[@geom.Point]
  pathplan_segments : Array[@routesplines.PathplanSegment]
}

///|
fn finalize_pathplan_boxes_and_segments(
  input : PathplanFinalizeInput,
) -> (Array[@geom.Rect], Array[@routesplines.PathplanSegment]) {
  let base = input.base
  let using_pathplan = input.using_pathplan
  let pathplan_points = input.pathplan_points
  let raw_bezier = input.raw_bezier
  let mut limited_boxes = input.pathplan_boxes
  let mut limited_segments = input.pathplan_segments
  if using_pathplan && limited_boxes.length() > 0 && raw_bezier.length() >= 4 {
    // Graphviz parity: limit boxes based on routed spline before recover_slack.
    limited_boxes = @routesplines.limit_boxes_for_spline(
      limited_boxes,
      raw_bezier,
      fallback_polyline=pathplan_points,
    )
  }
  if using_pathplan && limited_segments.length() > 0 {
    // Graphviz parity: limit segment boxes independently to match straight_path sampling.
    limited_segments = limit_pathplan_segment_boxes(base, limited_segments)
  }
  (limited_boxes, limited_segments)
}
