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
fn edge_polyline_points(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  nodesep_pt : Double,
  label_width_pt : Double,
  label_height_pt : Double?,
  dotted_weight : Double,
  use_cluster_tuning : Bool,
  split_label : Bool,
  same_local_cluster : Bool,
  default_vnode_weight : Double,
) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let tail_rank_opt = ranks.get(tail_name)
  let head_rank_opt = ranks.get(head_name)
  if vnodes.length() > 0 {
    match (tail_rank_opt, head_rank_opt) {
      (Some(tail_rank), Some(head_rank)) => {
        let span = head_rank - tail_rank
        if span == 0 {
          let push_flat_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                if label_width_pt > 0.0 {
                  let half = label_width_pt / 2.0
                  let bend_y =
                    match label_height_pt {
                      Some(height) => {
                        let label_top = pos.y + height / 2.0
                        let source_y =
                          if tail_anchor.x <= head_anchor.x {
                            tail_anchor.y
                          } else {
                            head_anchor.y
                          }
                        let ydelta = (pos.y - source_y) / 6.0
                        let lift = if ydelta > 5.0 { ydelta } else { 5.0 }
                        label_top - lift
                      }
                      None => pos.y
                    }
                  if tail_anchor.x <= head_anchor.x {
                    points.push({ x: pos.x - half, y: bend_y })
                    points.push({ x: pos.x + half, y: bend_y })
                  } else {
                    points.push({ x: pos.x + half, y: bend_y })
                    points.push({ x: pos.x - half, y: bend_y })
                  }
                } else {
                  points.push(pos)
                }
              None => ()
            }
          }
          if tail_anchor.x <= head_anchor.x {
            for name in vnodes {
              push_flat_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_flat_point(name)
            }
          }
        } else {
          let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
          let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
          let label_rank = if label_width_pt > 0.0 {
            (min_rank + max_rank) / 2
          } else {
            -1
          }
          let y_dir = if head_anchor.y < tail_anchor.y { 1.0 } else { -1.0 }
          let style_value = match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
          let is_dotted = style_value.contains("dotted")
          let has_explicit_port =
            @dot_shared.port_is_explicit(tail_port) || @dot_shared.port_is_explicit(head_port)
          let base_vnode_weight =
            if use_cluster_tuning {
              if is_dotted {
                if same_local_cluster { dotted_weight * 0.7 } else { dotted_weight }
              } else if split_label {
                0.3
              } else if label_width_pt > 0.0 && !has_explicit_port {
                if same_local_cluster {
                  1.0
                } else {
                  0.4
                }
              } else {
                0.0
              }
            } else {
              default_vnode_weight
            }
          let span_f = Double::from_int(span)
          let push_point = (name : String) => {
            match vnode_positions.get(name) {
              Some(pos) =>
                match vnode_ranks.get(name) {
                  Some(rank) => {
                    let t_raw = Double::from_int(rank - tail_rank) / span_f
                    let t =
                      if use_cluster_tuning && !is_dotted && head_anchor.x >= tail_anchor.x {
                        if split_label && rank == label_rank {
                          t_raw
                        } else {
                          t_raw * t_raw
                        }
                      } else {
                        t_raw
                      }
                    let interp_x = tail_anchor.x + (head_anchor.x - tail_anchor.x) * t
                    let base_y = match rank_y.get(rank) {
                      Some(value) => value
                      None => pos.y
                    }
                    let base_offset = match rank_ht1.get(rank) {
                      Some(value) => value
                      None => 0.0
                    }
                    let y = base_y + base_offset
                    let vnode_weight = base_vnode_weight
                    let x = pos.x * vnode_weight + interp_x * (1.0 - vnode_weight)
                    if split_label && rank == label_rank {
                      let split_width = label_width_pt * 1.5
                      let split_x = x - nodesep_pt * 1.25
                      points.push({
                        x: split_x - nodesep_pt,
                        y: y + nodesep_pt * y_dir,
                      })
                      points.push({
                        x: split_x + split_width * 0.5,
                        y: y - nodesep_pt * y_dir,
                      })
                    } else {
                      points.push({ x, y })
                    }
                  }
                  None => ()
                }
              None => ()
            }
          }
          if tail_rank <= head_rank {
            for name in vnodes {
              push_point(name)
            }
          } else {
            let mut idx = vnodes.length()
            while idx > 0 {
              idx = idx - 1
              let name = vnodes[idx]
              push_point(name)
            }
          }
        }
      }
      _ => ()
    }
  }
  points.push(head_anchor)
  points
}

///|
fn prepare_edge_curve_mode_route(
  base : @routing.EdgeRouteBase,
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
    edge_polyline_points(
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
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
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
  base : @routing.EdgeRouteBase,
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
) -> @routing.EdgeSplineResult {
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
  base : @routing.EdgeRouteBase,
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
) -> @routing.EdgeSplineResult {
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
