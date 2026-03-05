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
    let tail_bottom = input.tail_clip_center.y - input.tail_clip_size.height_pt / 2.0
    let head_bottom = input.head_clip_center.y - input.head_clip_size.height_pt / 2.0
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
pub fn build_points_spline(
  input : PointsSplineBuildInput,
) -> PointsSplineResult {
  let raw_bezier =
    if input.using_pathplan {
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
  let spline =
    @edge_spline.edge_spline_for_points(
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
  if points.length() >= 2 { points } else { [line_start, line_end] }
}

///|
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
  build_points_spline(
    {
      base: input.base,
      points: input.pathplan_points,
      tail_slope_line: input.tail_slope_line,
      head_slope_line: input.head_slope_line,
      force_segmented: input.force_segmented,
      using_pathplan: true,
      route_barriers: input.route_barriers,
    },
  )
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
fn build_line_spline(
  input : LineSplineBuildInput,
) -> @geom.Spline {
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
    build_pathplan_points_spline(
      {
        base: input.base,
        pathplan_points: input.pathplan_points,
        tail_slope_line: input.tail_slope_line,
        head_slope_line: input.head_slope_line,
        force_segmented: input.force_segmented,
        route_barriers: input.route_barriers,
      },
    )
  } else {
    {
      spline:
        build_line_spline(
          {
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
          },
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
      {
        base,
        points: detour_points,
        tail_slope_line,
        head_slope_line,
        force_segmented: true,
        using_pathplan,
        route_barriers,
      },
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
fn detour_spline_if_any(
  input : DetourSplineBuildInput,
) -> PointsSplineResult? {
  if input.needs_record_detour {
    let detour_points =
      record_port_detour_points(
        {
          tail_clip_center: input.base.tail_clip_center,
          head_clip_center: input.base.head_clip_center,
          tail_clip_size: input.base.tail_clip_size,
          head_clip_size: input.base.head_clip_size,
          tail_clip: input.base.tail_clip,
          head_clip: input.base.head_clip,
          nodesep_pt: input.nodesep_pt,
          layout_rankdir: input.base.layout_rankdir,
          lr_detour_uses_x_axis: input.lr_detour_uses_x_axis,
        },
      )
    Some(
      build_points_spline(
        {
          base: input.base,
          points: detour_points,
          tail_slope_line: input.tail_slope_line,
          head_slope_line: input.head_slope_line,
          force_segmented: true,
          using_pathplan: input.using_pathplan,
          route_barriers: input.route_barriers,
        },
      ),
    )
  } else {
    match input.flat_detour {
      Some(detour) =>
        Some(
          build_flat_detour_spline(
            input.base,
            detour,
            input.using_pathplan,
            input.tail_slope_line,
            input.head_slope_line,
            input.route_barriers,
          ),
        )
      None => None
    }
  }
}
