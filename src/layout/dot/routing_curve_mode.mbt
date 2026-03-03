///|
priv struct CurveModeRoutePrep {
  label_pad_boost : Double
  label_width_pt : Double
  has_explicit_port : Bool
  abs_dx : Double
  split_label : Bool
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  pathplan_segments : Array[@routesplines.PathplanSegment]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  points : Array[@geom.Point]
  short_route_context : ShortRouteBuildContext
}

///|
priv struct CurveModeSplineBuildResult {
  spline : @geom.Spline
  raw_bezier : Array[@geom.Point]
  apply_dotted_adjustment : Bool
}

///|
fn prepare_edge_curve_mode_route(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> CurveModeRoutePrep {
  let edge = base.edge
  let tail_anchor = base.tail_anchor
  let head_anchor = base.head_anchor
  let label_width_pt = edge_mid_label_width_pt(edge)
  let label_height_pt = match edge_mid_label_metrics(edge) {
    Some(metrics) => Some(metrics.height)
    None => None
  }
  let has_explicit_port =
    @dot_shared.port_is_explicit(base.tail_port) ||
    @dot_shared.port_is_explicit(base.head_port)
  let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
  let split_label = enable_complex_tuning &&
    label_width_pt > 0.0 &&
    base.same_outer_cluster &&
    base.diff_local_cluster &&
    abs_dx > label_width_pt
  let label_pad_boost = if split_label { nodesep_pt * 1.2 } else { 0.0 }
  let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
  let guide_points =
    @routing.edge_polyline_points(
      edge,
      base.tail_name,
      base.head_name,
      base.tail_port,
      base.head_port,
      tail_anchor,
      head_anchor,
      ranks,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
      vnode_positions,
      rank_y,
      rank_ht1,
      nodesep_pt,
      label_width_pt,
      label_height_pt,
      dotted_weight,
      enable_complex_tuning,
      split_label,
      base.same_local_cluster,
      DEFAULT_VNODE_WEIGHT,
    )
  let route_state =
    compute_pathplan_route_points(
      base,
      ranks,
      positions,
      vnode_positions,
      vnode_info,
      sizes,
      x_groups,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      routing_context,
      guide_points,
    )
  let using_pathplan = route_state.using_pathplan
  let points =
    adjust_route_points(
      route_state.points,
      base,
      base.head_port_rect,
      has_explicit_port,
      using_pathplan,
      nodesep_pt,
    )
  let curve_offset_params = compute_curve_offset(
    edge,
    base,
    head_port_metrics,
    label_width_pt,
    nodesep_pt,
    enable_complex_tuning,
  )
  let short_route_context =
    short_route_build_context(
      base,
      positions,
      sizes,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      ranksep_pt,
      route_state.route_barriers,
      using_pathplan,
      has_explicit_port,
      label_width_pt,
      nodesep_pt,
      base.force_segmented,
      curve_offset_params.curve_offset,
      curve_offset_params.curve_skew,
    )
  {
    label_pad_boost,
    label_width_pt,
    has_explicit_port,
    abs_dx,
    split_label,
    using_pathplan,
    pathplan_boxes: route_state.pathplan_boxes,
    pathplan_points: route_state.pathplan_points,
    pathplan_segments: route_state.pathplan_segments,
    route_barriers: route_state.route_barriers,
    points,
    short_route_context,
  }
}

///|
fn curve_mode_result_for_short_route(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  short_route_spec : ShortRouteBuildSpec,
) -> CurveModeSplineBuildResult {
  let short_route_spline =
    build_short_route_spline_with_detour(
      base,
      prepared.short_route_context,
      short_route_spec,
    )
  {
    spline: short_route_spline.spline,
    raw_bezier: short_route_spline.raw_bezier,
    apply_dotted_adjustment: false,
  }
}

///|
fn adjusted_curve_mode_points(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  label_edge_counts : Map[String, Int],
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> Array[@geom.Point] {
  let points = prepared.points
  let simplify_tol = nodesep_pt * 0.8
  let tail_label_edges = match label_edge_counts.get(base.orig_tail_name) {
    Some(value) => value > 1
    None => false
  }
  let keep_label_kink =
    prepared.label_width_pt > 0.0 &&
    (prepared.has_explicit_port ||
      (base.same_outer_cluster &&
          (prepared.abs_dx < nodesep_pt ||
            (tail_label_edges && prepared.abs_dx < prepared.label_width_pt))))
  let simplified =
    if prepared.using_pathplan {
      points
    } else if enable_complex_tuning &&
      base.has_vnodes &&
      !prepared.split_label &&
      !keep_label_kink {
      simplify_polyline(points, simplify_tol)
    } else {
      points
    }
  if !prepared.using_pathplan && base.is_dotted && base.same_outer_cluster {
    @edge_ops.adjust_intracluster_dots(simplified)
  } else {
    simplified
  }
}

///|
fn build_curve_mode_spline_from_prepared_route(
  base : EdgeRouteBase,
  prepared : CurveModeRoutePrep,
  label_edge_counts : Map[String, Int],
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> CurveModeSplineBuildResult {
  let points = prepared.points
  if points.length() > 2 {
    let adjusted =
      adjusted_curve_mode_points(
        base,
        prepared,
        label_edge_counts,
        nodesep_pt,
        enable_complex_tuning,
      )
    if adjusted.length() <= 2 {
      let short_route_spec = short_route_spec_for_adjusted_points(adjusted)
      curve_mode_result_for_short_route(base, prepared, short_route_spec)
    } else {
      let multi_point_spline =
        build_multi_point_routed_spline(
          base,
          adjusted,
          prepared.using_pathplan,
          base.force_segmented,
          prepared.pathplan_segments,
          prepared.route_barriers,
          base.tail_clip_enabled,
          base.head_clip_enabled,
        )
      {
        spline: multi_point_spline.spline,
        raw_bezier: multi_point_spline.raw_bezier,
        apply_dotted_adjustment: true,
      }
    }
  } else {
    let short_route_spec =
      short_route_spec_for_anchor_or_pathplan_points(
        points,
        prepared.using_pathplan,
        base.tail_anchor,
        base.head_anchor,
        base.tail_clip_enabled,
        base.head_clip_enabled,
      )
    curve_mode_result_for_short_route(base, prepared, short_route_spec)
  }
}

///|
fn build_edge_curve_mode_result(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  let prepared =
    prepare_edge_curve_mode_route(
      base,
      ranks,
      sizes,
      positions,
      vnode_positions,
      vnode_info,
      rank_y,
      rank_ht1,
      rank_ht2,
      x_groups,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      ranksep_pt,
      head_port_metrics,
      routing_context,
      enable_complex_tuning,
    )
  let spline_result =
    build_curve_mode_spline_from_prepared_route(
      base,
      prepared,
      label_edge_counts,
      nodesep_pt,
      enable_complex_tuning,
    )
  let (pathplan_boxes, pathplan_segments) =
    finalize_pathplan_boxes_and_segments(
      base,
      prepared.using_pathplan,
      prepared.pathplan_boxes,
      prepared.pathplan_points,
      spline_result.raw_bezier,
      prepared.pathplan_segments,
    )
  {
    spline: spline_result.spline,
    label_pad_boost: prepared.label_pad_boost,
    using_pathplan: prepared.using_pathplan,
    pathplan_boxes,
    pathplan_points: prepared.pathplan_points,
    raw_bezier: spline_result.raw_bezier,
    pathplan_segments,
    apply_dotted_adjustment: spline_result.apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: spline routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_spline(
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  match splines {
    SplinesMode::None | SplinesMode::Polyline =>
      @routing.edge_spline_result_for_bezier(
        @routing.edge_polyline_mode_spline(base, false),
        [],
        0.0,
        false,
      )
    SplinesMode::Ortho =>
      @routing.edge_spline_result_for_bezier(
        @routing.edge_polyline_mode_spline(base, true),
        [],
        0.0,
        false,
      )
    _ =>
      build_edge_curve_mode_result(
        base,
        ranks,
        sizes,
        positions,
        vnode_positions,
        vnode_info,
        rank_y,
        rank_ht1,
        rank_ht2,
        x_groups,
        nodesep_pt,
        path_left_bound,
        path_right_bound,
        ranksep_pt,
        label_edge_counts,
        head_port_metrics,
        routing_context,
        enable_complex_tuning,
      )
  }
}
