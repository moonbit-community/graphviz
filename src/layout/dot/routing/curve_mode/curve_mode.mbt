// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
/// Graphviz parity: curve-mode route input keeps rank/geometry/pathplan
/// snapshots grouped before guide-point and short-route preparation.
priv struct CurveModeRouteInput {
  base : EdgeRouteBase
  ranks : Map[String, Int]
  sizes : Map[String, NodeSize]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  path_left_bound : Double
  path_right_bound : Double
  ranksep_pt : Double
  has_graph_edge_labels : Bool
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
fn prepare_edge_curve_mode_route(
  input : CurveModeRouteInput,
) -> CurveModeRoutePrep {
  let edge = input.base.edge
  let tail_anchor = input.base.tail_anchor
  let head_anchor = input.base.head_anchor
  let label_width_pt = input.base.mid_label_width_pt
  let label_height_pt = if input.base.mid_label_height_pt > 0.0 {
    Some(input.base.mid_label_height_pt)
  } else {
    None
  }
  let has_explicit_port = @edge_identity.port_is_explicit(input.base.tail_port) ||
    @edge_identity.port_is_explicit(input.base.head_port)
  let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
  let split_label = input.enable_complex_tuning &&
    label_width_pt > 0.0 &&
    input.base.same_outer_cluster &&
    input.base.diff_local_cluster &&
    abs_dx > label_width_pt
  let label_pad_boost = if split_label { input.nodesep_pt * 1.2 } else { 0.0 }
  let dotted_weight = if input.enable_complex_tuning { 1.0 } else { 0.8 }
  let guide_points = edge_polyline_points({
    edge,
    tail_name: input.base.tail_name,
    head_name: input.base.head_name,
    tail_port: input.base.tail_port,
    head_port: input.base.head_port,
    tail_anchor,
    head_anchor,
    ranks: input.ranks,
    edge_vnodes: input.vnode_info.edge_vnodes,
    vnode_ranks: input.vnode_info.vnode_ranks,
    vnode_positions: input.vnode_positions,
    rank_y: input.rank_y,
    rank_ht1: input.rank_ht1,
    nodesep_pt: input.nodesep_pt,
    label_width_pt,
    label_height_pt,
    dotted_weight,
    use_cluster_tuning: input.enable_complex_tuning,
    split_label,
    same_local_cluster: input.base.same_local_cluster,
    default_vnode_weight: DEFAULT_VNODE_WEIGHT,
  })
  let route_state = compute_pathplan_route_points({
    base: input.base,
    has_any_edge_label: input.has_graph_edge_labels,
    ranks: input.ranks,
    vnode_info: input.vnode_info,
    x_groups: input.x_groups,
    rank_y: input.rank_y,
    rank_ht1: input.rank_ht1,
    rank_ht2: input.rank_ht2,
    nodesep_pt: input.nodesep_pt,
    path_left_bound: input.path_left_bound,
    path_right_bound: input.path_right_bound,
    ranksep_pt: input.ranksep_pt,
    routing_context: input.routing_context,
    guide_points,
  })
  let using_pathplan = route_state.using_pathplan
  let points = adjust_route_points({
    points: route_state.points,
    base: input.base,
    head_port_rect: input.base.head_port_rect,
    has_explicit_port,
    using_pathplan,
    nodesep_pt: input.nodesep_pt,
  })
  let curve_offset_params = compute_curve_offset({
    edge,
    base: input.base,
    head_port_metrics: input.head_port_metrics,
    label_width_pt,
    nodesep_pt: input.nodesep_pt,
    enable_complex_tuning: input.enable_complex_tuning,
  })
  let short_route_context = short_route_build_context({
    base: input.base,
    positions: input.positions,
    sizes: input.sizes,
    ranks: input.ranks,
    rank_y: input.rank_y,
    rank_ht1: input.rank_ht1,
    rank_ht2: input.rank_ht2,
    ranksep_pt: input.ranksep_pt,
    route_barriers: route_state.route_barriers,
    using_pathplan,
    has_explicit_port,
    label_width_pt,
    nodesep_pt: input.nodesep_pt,
    force_segmented: input.base.force_segmented,
    curve_offset: curve_offset_params.curve_offset,
    curve_skew: curve_offset_params.curve_skew,
  })
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
  let short_route_spline = build_short_route_spline_with_detour(
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
priv struct CurveModeSplineFromPreparedInput {
  base : EdgeRouteBase
  prepared : CurveModeRoutePrep
  label_edge_counts : Map[String, Int]
  nodesep_pt : Double
  enable_complex_tuning : Bool
}

///|
fn build_curve_mode_spline_from_prepared_route(
  input : CurveModeSplineFromPreparedInput,
) -> CurveModeSplineBuildResult {
  let base = input.base
  let prepared = input.prepared
  let label_edge_counts = input.label_edge_counts
  let nodesep_pt = input.nodesep_pt
  let enable_complex_tuning = input.enable_complex_tuning
  let points = prepared.points
  if points.length() > 2 {
    let adjusted = adjusted_curve_mode_points({
      base,
      prepared,
      label_edge_counts,
      nodesep_pt,
      enable_complex_tuning,
    })
    if adjusted.length() <= 2 {
      let short_route_spec = short_route_spec_for_adjusted_points(adjusted)
      curve_mode_result_for_short_route(base, prepared, short_route_spec)
    } else {
      let multi_point_spline = build_multi_point_routed_spline({
        base,
        adjusted,
        using_pathplan: prepared.using_pathplan,
        force_segmented: base.force_segmented,
        pathplan_segments: prepared.pathplan_segments,
        route_barriers: prepared.route_barriers,
        tail_clip_enabled: base.tail_clip_enabled,
        head_clip_enabled: base.head_clip_enabled,
      })
      {
        spline: multi_point_spline.spline,
        raw_bezier: multi_point_spline.raw_bezier,
        apply_dotted_adjustment: true,
      }
    }
  } else {
    let short_route_spec = short_route_spec_for_anchor_or_pathplan_points({
      points,
      using_pathplan: prepared.using_pathplan,
      tail_anchor: base.tail_anchor,
      head_anchor: base.head_anchor,
      tail_clip_enabled: base.tail_clip_enabled,
      head_clip_enabled: base.head_clip_enabled,
    })
    curve_mode_result_for_short_route(base, prepared, short_route_spec)
  }
}

///|
fn build_edge_curve_mode_result(
  input : CurveModeRouteInput,
) -> EdgeSplineResult {
  let prepared = prepare_edge_curve_mode_route(input)
  let spline_result = build_curve_mode_spline_from_prepared_route({
    base: input.base,
    prepared,
    label_edge_counts: input.label_edge_counts,
    nodesep_pt: input.nodesep_pt,
    enable_complex_tuning: input.enable_complex_tuning,
  })
  let (pathplan_boxes, pathplan_segments) = finalize_pathplan_boxes_and_segments({
      base: input.base,
      using_pathplan: prepared.using_pathplan,
      pathplan_boxes: prepared.pathplan_boxes,
      pathplan_points: prepared.pathplan_points,
      raw_bezier: spline_result.raw_bezier,
      pathplan_segments: prepared.pathplan_segments,
    },
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
pub fn build_edge_spline(input : EdgeSplineBuildInput) -> EdgeSplineResult {
  if input.spline_mode == 0 {
    @emit.edge_spline_result_for_bezier(
      @emit.edge_polyline_mode_spline(input.base, false),
      [],
      0.0,
      false,
    )
  } else if input.spline_mode == 1 {
    @emit.edge_spline_result_for_bezier(
      @emit.edge_polyline_mode_spline(input.base, true),
      [],
      0.0,
      false,
    )
  } else {
    build_edge_curve_mode_result({
      base: input.base,
      ranks: input.ranks,
      sizes: input.sizes,
      positions: input.positions,
      vnode_positions: input.vnode_positions,
      vnode_info: input.vnode_info,
      rank_y: input.rank_y,
      rank_ht1: input.rank_ht1,
      rank_ht2: input.rank_ht2,
      x_groups: input.x_groups,
      nodesep_pt: input.nodesep_pt,
      path_left_bound: input.path_left_bound,
      path_right_bound: input.path_right_bound,
      ranksep_pt: input.ranksep_pt,
      has_graph_edge_labels: input.has_graph_edge_labels,
      label_edge_counts: input.label_edge_counts,
      head_port_metrics: input.head_port_metrics,
      routing_context: input.routing_context,
      enable_complex_tuning: input.enable_complex_tuning,
    })
  }
}

///|
/// Graphviz parity: spline-build input keeps route geometry/rank snapshots
/// grouped for one spline-mode dispatch boundary.
pub(all) struct EdgeSplineBuildInput {
  base : EdgeRouteBase
  spline_mode : Int
  ranks : Map[String, Int]
  sizes : Map[String, NodeSize]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  path_left_bound : Double
  path_right_bound : Double
  ranksep_pt : Double
  has_graph_edge_labels : Bool
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
priv struct CurveOffsetParams {
  curve_offset : Double
  curve_skew : Double
}

///|
priv struct CurveOffsetInput {
  edge : @cgraph.Edge
  base : EdgeRouteBase
  head_port_metrics : HeadPortMetrics
  label_width_pt : Double
  nodesep_pt : Double
  enable_complex_tuning : Bool
}

///|
/// Graphviz parity: curve offset tuning aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_curve_offset(input : CurveOffsetInput) -> CurveOffsetParams {
  let edge = input.edge
  let base = input.base
  let head_port_metrics = input.head_port_metrics
  let label_width_pt = input.label_width_pt
  let nodesep_pt = input.nodesep_pt
  let enable_complex_tuning = input.enable_complex_tuning
  let mut curve_offset = 0.0
  let mut curve_skew = 1.0
  if enable_complex_tuning {
    let head_port_key = @edge_identity.port_key(edge.head_port())
    let key = if head_port_key == "" {
      if @record_geometry.is_record_shape(edge.head()) {
        base.orig_head_name
      } else {
        ""
      }
    } else {
      "\{base.orig_head_name}:\{head_port_key}"
    }
    if key != "" {
      let count = head_port_metrics.head_port_counts
        .get(key)
        .unwrap_or_default()
      if count > 1 {
        let dx = base.head_anchor.x - base.tail_anchor.x
        let dy = base.head_anchor.y - base.tail_anchor.y
        let dist = Double::sqrt(dx * dx + dy * dy)
        let min_dist = match head_port_metrics.head_port_min_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let max_dist = match head_port_metrics.head_port_max_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let span = max_dist - min_dist
        if span > 0.0 {
          let t = (dist - min_dist) / span
          let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
          let port_scale = if head_port_key == "" { 0.6 } else { 0.6 }
          curve_offset = nodesep_pt * t * t * label_factor * port_scale
          if head_port_key != "" {
            match base.layout_rankdir {
              RankDir::TB | RankDir::BT => if dx < 0.0 { curve_skew = 0.5 }
              RankDir::LR | RankDir::RL => if dy < 0.0 { curve_skew = 0.5 }
            }
          }
        }
      }
    }
  }
  { curve_offset, curve_skew }
}
