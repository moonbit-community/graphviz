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
priv struct RecordPortDetourNeedInput {
  using_pathplan : Bool
  is_flat_edge : Bool
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_slope_line : @geom.Point
  head_slope_line : @geom.Point
  layout_rankdir : RankDir
}

///|
fn needs_record_port_detour(
  input : RecordPortDetourNeedInput,
) -> Bool {
  let record_port_edge =
    (
      @record_geometry.is_record_shape(input.tail_node) &&
      @edge_identity.port_is_explicit(input.tail_port)
    ) ||
    (
      @record_geometry.is_record_shape(input.head_node) &&
      @edge_identity.port_is_explicit(input.head_port)
    )
  !input.using_pathplan &&
  !input.is_flat_edge &&
  record_port_edge &&
  (match input.layout_rankdir {
    RankDir::TB | RankDir::BT =>
      Double::abs(input.tail_slope_line.x) > 0.01 ||
      Double::abs(input.head_slope_line.x) > 0.01
    RankDir::LR | RankDir::RL =>
      Double::abs(input.tail_slope_line.y) > 0.01 ||
      Double::abs(input.head_slope_line.y) > 0.01
  })
}

///|
priv struct FlatDetourCandidateFlags {
  no_arrow : Bool
  top_single_arrow : Bool
}

///|
/// Graphviz parity: flat-detour candidate input keeps arrow/port/rankdir flags
/// grouped so flat short-route detour gates remain explicit and stable.
priv struct FlatDetourCandidateInput {
  using_pathplan : Bool
  is_flat_edge : Bool
  has_explicit_port : Bool
  label_width_pt : Double
  tail_port_side : Int
  head_port_side : Int
  layout_rankdir : RankDir
  route_include_tail : Bool
  route_include_head : Bool
}

///|
fn flat_detour_candidate_flags(
  input : FlatDetourCandidateInput,
) -> FlatDetourCandidateFlags {
  let no_arrow =
    !input.using_pathplan &&
    input.is_flat_edge &&
    !input.has_explicit_port &&
    input.label_width_pt <= 0.0 &&
    route_has_no_arrowheads(input.route_include_tail, input.route_include_head)
  let top_single_arrow =
    !input.using_pathplan &&
    input.is_flat_edge &&
    input.has_explicit_port &&
    input.label_width_pt <= 0.0 &&
    (input.tail_port_side & PORT_SIDE_TOP) != 0 &&
    (input.head_port_side & PORT_SIDE_TOP) != 0 &&
    (input.tail_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (input.head_port_side & PORT_SIDE_BOTTOM) == 0 &&
    (input.layout_rankdir == RankDir::TB || input.layout_rankdir == RankDir::BT) &&
    route_has_single_arrowhead(input.route_include_tail, input.route_include_head)
  { no_arrow, top_single_arrow }
}

///|
fn edge_port_slope_or_zero(
  port : @cgraph.Port?,
  slope : @geom.Point,
) -> @geom.Point {
  if @edge_identity.port_is_explicit(port) { slope } else { @edge_spline.point(0.0, 0.0) }
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
/// Graphviz parity: short-route detour context input keeps edge geometry,
/// port/arrow flags, and rankdir grouped for one detour gate evaluation.
priv struct ShortRouteDetourContextInput {
  using_pathplan : Bool
  is_flat_edge : Bool
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_slope : @geom.Point
  head_slope : @geom.Point
  layout_rankdir : RankDir
  has_explicit_port : Bool
  label_width_pt : Double
  tail_port_side : Int
  head_port_side : Int
  route_include_tail : Bool
  route_include_head : Bool
}

///|
fn short_route_detour_context(
  input : ShortRouteDetourContextInput,
) -> ShortRouteDetourContext {
  let tail_slope_line = edge_port_slope_or_zero(input.tail_port, input.tail_slope)
  let head_slope_line = edge_port_slope_or_zero(input.head_port, input.head_slope)
  let needs_record_detour =
    needs_record_port_detour(
      {
        using_pathplan: input.using_pathplan,
        is_flat_edge: input.is_flat_edge,
        tail_node: input.tail_node,
        head_node: input.head_node,
        tail_port: input.tail_port,
        head_port: input.head_port,
        tail_slope_line,
        head_slope_line,
        layout_rankdir: input.layout_rankdir,
      },
    )
  let flat_detour_flags =
    flat_detour_candidate_flags(
      {
        using_pathplan: input.using_pathplan,
        is_flat_edge: input.is_flat_edge,
        has_explicit_port: input.has_explicit_port,
        label_width_pt: input.label_width_pt,
        tail_port_side: input.tail_port_side,
        head_port_side: input.head_port_side,
        layout_rankdir: input.layout_rankdir,
        route_include_tail: input.route_include_tail,
        route_include_head: input.route_include_head,
      },
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
    {
      using_pathplan,
      is_flat_edge: base.is_flat_edge,
      tail_node: base.tail_node,
      head_node: base.head_node,
      tail_port: base.tail_port,
      head_port: base.head_port,
      tail_slope: base.tail_slope,
      head_slope: base.head_slope,
      layout_rankdir: base.layout_rankdir,
      has_explicit_port,
      label_width_pt,
      tail_port_side: base.tail_port_side,
      head_port_side: base.head_port_side,
      route_include_tail: base.route_include_tail,
      route_include_head: base.route_include_head,
    },
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
/// Graphviz parity: short-route build-context input keeps geometry/rank maps
/// and short-route tuning flags grouped before detour lookup setup.
pub(all) struct ShortRouteBuildContextInput {
  base : EdgeRouteBase
  positions : Map[String, @geom.Point]
  sizes : Map[String, NodeSize]
  ranks : Map[String, Int]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
  route_barriers : Array[(@geom.Point, @geom.Point)]
  using_pathplan : Bool
  has_explicit_port : Bool
  label_width_pt : Double
  nodesep_pt : Double
  force_segmented : Bool
  curve_offset : Double
  curve_skew : Double
}

///|
/// Graphviz parity: short-route fallback input keeps detour outcome, line
/// endpoints, and slope/clip controls grouped for one fallback build path.
priv struct ShortRouteFallbackBuildInput {
  base : EdgeRouteBase
  using_pathplan : Bool
  pathplan_points : Array[@geom.Point]
  line_start : @geom.Point
  line_end : @geom.Point
  detour_context : ShortRouteDetourContext
  detour_resolution : ShortRouteDetourResolution
  force_segmented : Bool
  route_barriers : Array[(@geom.Point, @geom.Point)]
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  curve_offset : Double
  curve_skew : Double
  prefer_linear_flat_invis : Bool
  prefer_linear_flat_bottom_single_arrow : Bool
}

///|
fn build_short_route_fallback_spline(
  input : ShortRouteFallbackBuildInput,
) -> PointsSplineResult {
  let prefer_linear_flat_line =
    prefer_linear_for_flat_line(
      input.prefer_linear_flat_invis,
      input.detour_resolution.flat_no_arrow_candidate,
      input.detour_resolution.has_flat_detour,
      input.prefer_linear_flat_bottom_single_arrow,
    )
  build_short_route_line_or_pathplan_spline(
    {
      base: input.base,
      using_pathplan: input.using_pathplan,
      pathplan_points: input.pathplan_points,
      line_start: input.line_start,
      line_end: input.line_end,
      tail_slope_line: input.detour_context.tail_slope_line,
      head_slope_line: input.detour_context.head_slope_line,
      force_segmented: input.force_segmented,
      route_barriers: input.route_barriers,
      tail_clip_enabled: input.tail_clip_enabled,
      head_clip_enabled: input.head_clip_enabled,
      curve_offset: input.curve_offset,
      curve_skew: input.curve_skew,
      prefer_linear: prefer_linear_flat_line,
    },
  )
}

///|
fn short_route_build_context(
  input : ShortRouteBuildContextInput,
) -> ShortRouteBuildContext {
  let style_value = match input.base.edge.get_attr("style") {
    Some(value) => value.to_lower()
    None => ""
  }
  // Graphviz parity: flat invisible edges use linear control points in
  // line routing (matches proc3d rank=same invis edge snapshots).
  let prefer_linear_flat_invis =
    input.base.is_flat_edge &&
    !input.has_explicit_port &&
    input.label_width_pt <= 0.0 &&
    style_value.contains("invis")
  let prefer_linear_flat_bottom_single_arrow =
    input.base.is_flat_edge &&
    !input.base.is_flat_adjacent &&
    !input.base.swap_ends &&
    input.has_explicit_port &&
    input.label_width_pt <= 0.0 &&
    (input.base.tail_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (input.base.head_port_side & PORT_SIDE_BOTTOM) != 0 &&
    (input.base.tail_port_side & PORT_SIDE_TOP) == 0 &&
    (input.base.head_port_side & PORT_SIDE_TOP) == 0 &&
    route_has_single_arrowhead(input.base.route_include_tail, input.base.route_include_head)
  let flat_detour_lookup =
    flat_detour_lookup_context(
      {
        base: input.base,
        positions: input.positions,
        sizes: input.sizes,
        ranks: input.ranks,
        rank_y: input.rank_y,
        rank_ht1: input.rank_ht1,
        rank_ht2: input.rank_ht2,
        ranksep_pt: input.ranksep_pt,
      },
    )
  {
    using_pathplan: input.using_pathplan,
    has_explicit_port: input.has_explicit_port,
    label_width_pt: input.label_width_pt,
    flat_detour_lookup,
    route_barriers: input.route_barriers,
    nodesep_pt: input.nodesep_pt,
    force_segmented: input.force_segmented,
    curve_offset: input.curve_offset,
    curve_skew: input.curve_skew,
    prefer_linear_flat_invis,
    prefer_linear_flat_bottom_single_arrow,
  }
}

///|
fn short_route_spec_for_adjusted_points(
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
pub(all) struct ShortRouteSpecFromAnchorInput {
  points : Array[@geom.Point]
  using_pathplan : Bool
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
}

///|
fn short_route_spec_for_anchor_or_pathplan_points(
  input : ShortRouteSpecFromAnchorInput,
) -> ShortRouteBuildSpec {
  let points = input.points
  let using_pathplan = input.using_pathplan
  let tail_anchor = input.tail_anchor
  let head_anchor = input.head_anchor
  let tail_clip_enabled = input.tail_clip_enabled
  let head_clip_enabled = input.head_clip_enabled
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
fn build_short_route_spline_with_detour(
  base : EdgeRouteBase,
  short_route_context : ShortRouteBuildContext,
  short_route_spec : ShortRouteBuildSpec,
) -> PointsSplineResult {
  let (detour_context, detour_resolution) =
    resolve_short_route_detour_for_base(
      {
        base,
        using_pathplan: short_route_context.using_pathplan,
        has_explicit_port: short_route_context.has_explicit_port,
        label_width_pt: short_route_context.label_width_pt,
        flat_detour_lookup: short_route_context.flat_detour_lookup,
        line_start: short_route_spec.detour_line_start,
        line_end: short_route_spec.detour_line_end,
        route_barriers: short_route_context.route_barriers,
        nodesep_pt: short_route_context.nodesep_pt,
        lr_detour_uses_x_axis: short_route_spec.lr_detour_uses_x_axis,
      },
    )
  if detour_resolution.detour_spline is Some(result) {
    result
  } else {
    let (line_start, line_end) =
      bottom_single_arrow_line_endpoints(
        {
          prefer_linear_flat_bottom_single_arrow:
            short_route_context.prefer_linear_flat_bottom_single_arrow,
          line_start: short_route_spec.fallback_line_start,
          line_end: short_route_spec.fallback_line_end,
          tail_clip_center: base.tail_clip_center,
          head_clip_center: base.head_clip_center,
          tail_clip_size: base.tail_clip_size,
          head_clip_size: base.head_clip_size,
        },
      )
    let line_points =
      pathplan_line_points_or_endpoints(
        short_route_spec.fallback_points,
        line_start,
        line_end,
      )
    build_short_route_fallback_spline(
      {
        base,
        using_pathplan: short_route_context.using_pathplan,
        pathplan_points: line_points,
        line_start,
        line_end,
        detour_context,
        detour_resolution,
        force_segmented: short_route_context.force_segmented,
        route_barriers: short_route_context.route_barriers,
        tail_clip_enabled: short_route_spec.tail_clip_enabled,
        head_clip_enabled: short_route_spec.head_clip_enabled,
        curve_offset: short_route_context.curve_offset,
        curve_skew: short_route_context.curve_skew,
        prefer_linear_flat_invis: short_route_context.prefer_linear_flat_invis,
        prefer_linear_flat_bottom_single_arrow:
          short_route_context.prefer_linear_flat_bottom_single_arrow,
      },
    )
  }
}
