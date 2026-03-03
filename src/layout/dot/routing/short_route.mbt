///|
fn route_has_no_arrowheads(
  route_include_tail : Bool,
  route_include_head : Bool,
) -> Bool {
  !route_include_tail && !route_include_head
}

///|
fn route_has_single_arrowhead(
  route_include_tail : Bool,
  route_include_head : Bool,
) -> Bool {
  route_include_tail != route_include_head
}

///|
fn short_route_is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) =>
      match value.to_lower() {
        "record" | "mrecord" => true
        _ => false
      }
    None => false
  }
}

///|
fn needs_record_port_detour(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  tail_node : @cgraph.Node,
  head_node : @cgraph.Node,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_slope_line : @geom.Point,
  head_slope_line : @geom.Point,
  layout_rankdir : RankDir,
) -> Bool {
  let record_port_edge =
    (
      short_route_is_record_shape(tail_node) &&
      @dot_shared.port_is_explicit(tail_port)
    ) ||
    (
      short_route_is_record_shape(head_node) &&
      @dot_shared.port_is_explicit(head_port)
    )
  !using_pathplan &&
  !is_flat_edge &&
  record_port_edge &&
  (match layout_rankdir {
    RankDir::TB | RankDir::BT =>
      Double::abs(tail_slope_line.x) > 0.01 ||
      Double::abs(head_slope_line.x) > 0.01
    RankDir::LR | RankDir::RL =>
      Double::abs(tail_slope_line.y) > 0.01 ||
      Double::abs(head_slope_line.y) > 0.01
  })
}

///|
priv struct FlatDetourCandidateFlags {
  no_arrow : Bool
  top_single_arrow : Bool
}

///|
fn flat_detour_candidate_flags(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
  tail_port_side : Int,
  head_port_side : Int,
  layout_rankdir : RankDir,
  route_include_tail : Bool,
  route_include_head : Bool,
) -> FlatDetourCandidateFlags {
  let no_arrow =
    !using_pathplan &&
    is_flat_edge &&
    !has_explicit_port &&
    label_width_pt <= 0.0 &&
    route_has_no_arrowheads(route_include_tail, route_include_head)
  let top_single_arrow =
    !using_pathplan &&
    is_flat_edge &&
    has_explicit_port &&
    label_width_pt <= 0.0 &&
    (tail_port_side & PORT_SIDE_TOP) != 0 &&
    (head_port_side & PORT_SIDE_TOP) != 0 &&
    (tail_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (head_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (layout_rankdir == RankDir::TB || layout_rankdir == RankDir::BT) &&
    route_has_single_arrowhead(route_include_tail, route_include_head)
  { no_arrow, top_single_arrow }
}

///|
pub fn edge_port_slope_or_zero(
  port : @cgraph.Port?,
  slope : @geom.Point,
) -> @geom.Point {
  if @dot_shared.port_is_explicit(port) { slope } else { @edge_spline.point(0.0, 0.0) }
}

///|
priv struct ShortRouteDetourContext {
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  needs_record_detour : Bool
  flat_no_arrow_candidate : Bool
  flat_top_compass_single_arrow_candidate : Bool
}

///|
fn short_route_detour_context(
  using_pathplan : Bool,
  is_flat_edge : Bool,
  tail_node : @cgraph.Node,
  head_node : @cgraph.Node,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  layout_rankdir : RankDir,
  has_explicit_port : Bool,
  label_width_pt : Double,
  tail_port_side : Int,
  head_port_side : Int,
  route_include_tail : Bool,
  route_include_head : Bool,
) -> ShortRouteDetourContext {
  let tail_slope_line = edge_port_slope_or_zero(tail_port, tail_slope)
  let head_slope_line = edge_port_slope_or_zero(head_port, head_slope)
  let needs_record_detour =
    needs_record_port_detour(
      using_pathplan,
      is_flat_edge,
      tail_node,
      head_node,
      tail_port,
      head_port,
      tail_slope_line,
      head_slope_line,
      layout_rankdir,
    )
  let flat_detour_flags =
    flat_detour_candidate_flags(
      using_pathplan,
      is_flat_edge,
      has_explicit_port,
      label_width_pt,
      tail_port_side,
      head_port_side,
      layout_rankdir,
      route_include_tail,
      route_include_head,
    )
  {
    tail_slope_line,
    head_slope_line,
    needs_record_detour,
    flat_no_arrow_candidate: flat_detour_flags.no_arrow,
    flat_top_compass_single_arrow_candidate: flat_detour_flags.top_single_arrow,
  }
}

///|
fn short_route_detour_context_for_base(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
) -> ShortRouteDetourContext {
  short_route_detour_context(
    using_pathplan,
    base.is_flat_edge,
    base.tail_node,
    base.head_node,
    base.tail_port,
    base.head_port,
    base.tail_slope,
    base.head_slope,
    base.layout_rankdir,
    has_explicit_port,
    label_width_pt,
    base.tail_port_side,
    base.head_port_side,
    base.route_include_tail,
    base.route_include_head,
  )
}

///|
pub(all) struct PointsSplineResult {
  spline : @geom.Spline
  raw_bezier : Array[@geom.Point]
}

///|
pub(all) struct ShortRouteBuildSpec {
  detour_line_start : @geom.Point
  detour_line_end : @geom.Point
  fallback_points : Array[@geom.Point]
  fallback_line_start : @geom.Point
  fallback_line_end : @geom.Point
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  lr_detour_uses_x_axis : Bool
}

///|
pub(all) struct ShortRouteBuildContext {
  using_pathplan : Bool
  has_explicit_port : Bool
  label_width_pt : Double
  flat_detour_lookup : FlatDetourLookupContext
  route_barriers : Array[(@geom.Point, @geom.Point)]
  nodesep_pt : Double
  force_segmented : Bool
  curve_offset : Double
  curve_skew : Double
  prefer_linear_flat_invis : Bool
  prefer_linear_flat_bottom_single_arrow : Bool
}

///|
fn build_short_route_fallback_spline(
  base : EdgeRouteBase,
  using_pathplan : Bool,
  pathplan_points : Array[@geom.Point],
  line_start : @geom.Point,
  line_end : @geom.Point,
  detour_context : ShortRouteDetourContext,
  detour_resolution : ShortRouteDetourResolution,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
  curve_offset : Double,
  curve_skew : Double,
  prefer_linear_flat_invis : Bool,
  prefer_linear_flat_bottom_single_arrow : Bool,
) -> PointsSplineResult {
  let prefer_linear_flat_line =
    prefer_linear_for_flat_line(
      prefer_linear_flat_invis,
      detour_resolution.flat_no_arrow_candidate,
      detour_resolution.has_flat_detour,
      prefer_linear_flat_bottom_single_arrow,
    )
  build_short_route_line_or_pathplan_spline(
    base,
    using_pathplan,
    pathplan_points,
    line_start,
    line_end,
    detour_context.tail_slope_line,
    detour_context.head_slope_line,
    force_segmented,
    route_barriers,
    tail_clip_enabled,
    head_clip_enabled,
    curve_offset,
    curve_skew,
    prefer_linear_flat_line,
  )
}

///|
pub fn short_route_build_context(
  base : EdgeRouteBase,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  route_barriers : Array[(@geom.Point, @geom.Point)],
  using_pathplan : Bool,
  has_explicit_port : Bool,
  label_width_pt : Double,
  nodesep_pt : Double,
  force_segmented : Bool,
  curve_offset : Double,
  curve_skew : Double,
) -> ShortRouteBuildContext {
  let style_value = match base.edge.get_attr("style") {
    Some(value) => value.to_lower()
    None => ""
  }
  // Graphviz parity: flat invisible edges use linear control points in
  // line routing (matches proc3d rank=same invis edge snapshots).
  let prefer_linear_flat_invis =
    base.is_flat_edge &&
    !has_explicit_port &&
    label_width_pt <= 0.0 &&
    style_value.contains("invis")
  let prefer_linear_flat_bottom_single_arrow =
    base.is_flat_edge &&
    !base.is_flat_adjacent &&
    !base.swap_ends &&
    has_explicit_port &&
    label_width_pt <= 0.0 &&
    (base.tail_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (base.head_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (base.tail_port_side & PORT_SIDE_TOP) == 0 &&
    (base.head_port_side & PORT_SIDE_TOP) == 0 &&
    route_has_single_arrowhead(base.route_include_tail, base.route_include_head)
  let flat_detour_lookup =
    flat_detour_lookup_context(
      base,
      positions,
      sizes,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      ranksep_pt,
    )
  {
    using_pathplan,
    has_explicit_port,
    label_width_pt,
    flat_detour_lookup,
    route_barriers,
    nodesep_pt,
    force_segmented,
    curve_offset,
    curve_skew,
    prefer_linear_flat_invis,
    prefer_linear_flat_bottom_single_arrow,
  }
}

///|
pub fn short_route_spec_for_adjusted_points(
  adjusted : Array[@geom.Point],
) -> ShortRouteBuildSpec {
  {
    detour_line_start: adjusted[0],
    detour_line_end: adjusted[adjusted.length() - 1],
    fallback_points: adjusted,
    fallback_line_start: adjusted[0],
    fallback_line_end: adjusted[adjusted.length() - 1],
    tail_clip_enabled: true,
    head_clip_enabled: true,
    lr_detour_uses_x_axis: true,
  }
}

///|
pub fn short_route_spec_for_anchor_or_pathplan_points(
  points : Array[@geom.Point],
  using_pathplan : Bool,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  tail_clip_enabled : Bool,
  head_clip_enabled : Bool,
) -> ShortRouteBuildSpec {
  let fallback_line_start =
    if using_pathplan && points.length() >= 2 {
      points[0]
    } else {
      tail_anchor
    }
  let fallback_line_end =
    if using_pathplan && points.length() >= 2 {
      points[points.length() - 1]
    } else {
      head_anchor
    }
  {
    detour_line_start: tail_anchor,
    detour_line_end: head_anchor,
    fallback_points: points,
    fallback_line_start,
    fallback_line_end,
    tail_clip_enabled,
    head_clip_enabled,
    lr_detour_uses_x_axis: false,
  }
}

///|
pub fn build_short_route_spline_with_detour(
  base : EdgeRouteBase,
  short_route_context : ShortRouteBuildContext,
  short_route_spec : ShortRouteBuildSpec,
) -> PointsSplineResult {
  let (detour_context, detour_resolution) =
    resolve_short_route_detour_for_base(
      base,
      short_route_context.using_pathplan,
      short_route_context.has_explicit_port,
      short_route_context.label_width_pt,
      short_route_context.flat_detour_lookup,
      short_route_spec.detour_line_start,
      short_route_spec.detour_line_end,
      short_route_context.route_barriers,
      short_route_context.nodesep_pt,
      short_route_spec.lr_detour_uses_x_axis,
    )
  if detour_resolution.detour_spline is Some(result) {
    result
  } else {
    let (line_start, line_end) =
      bottom_single_arrow_line_endpoints(
        short_route_context.prefer_linear_flat_bottom_single_arrow,
        short_route_spec.fallback_line_start,
        short_route_spec.fallback_line_end,
        base.tail_clip_center,
        base.head_clip_center,
        base.tail_clip_size,
        base.head_clip_size,
      )
    let line_points =
      pathplan_line_points_or_endpoints(
        short_route_spec.fallback_points,
        line_start,
        line_end,
      )
    build_short_route_fallback_spline(
      base,
      short_route_context.using_pathplan,
      line_points,
      line_start,
      line_end,
      detour_context,
      detour_resolution,
      short_route_context.force_segmented,
      short_route_context.route_barriers,
      short_route_spec.tail_clip_enabled,
      short_route_spec.head_clip_enabled,
      short_route_context.curve_offset,
      short_route_context.curve_skew,
      short_route_context.prefer_linear_flat_invis,
      short_route_context.prefer_linear_flat_bottom_single_arrow,
    )
  }
}
