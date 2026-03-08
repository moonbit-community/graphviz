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
fn curve_point_line_distance(
  point : @geom.Point,
  a : @geom.Point,
  b : @geom.Point,
) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  if dx == 0.0 && dy == 0.0 {
    let pdx = point.x - a.x
    let pdy = point.y - a.y
    return Double::sqrt(pdx * pdx + pdy * pdy)
  }
  let t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
  let proj = @geom.Point::{ x: a.x + t * dx, y: a.y + t * dy }
  let pdx = point.x - proj.x
  let pdy = point.y - proj.y
  Double::sqrt(pdx * pdx + pdy * pdy)
}

///|
fn segment_intersects_rect(
  start : @geom.Point,
  end : @geom.Point,
  rect : @geom.Rect,
  eps : Double,
) -> Bool {
  let dx = end.x - start.x
  let dy = end.y - start.y
  let mut t0 = 0.0
  let mut t1 = 1.0
  let update = (p : Double, q : Double) => {
    if Double::abs(p) < 0.0000001 {
      if q < 0.0 { return false } else { return true }
    }
    let r = q / p
    if p < 0.0 {
      if r > t1 { return false }
      if r > t0 { t0 = r }
    } else {
      if r < t0 { return false }
      if r < t1 { t1 = r }
    }
    true
  }
  if !update(-dx, start.x - rect.llx) { return false }
  if !update(dx, rect.urx - start.x) { return false }
  if !update(-dy, start.y - rect.lly) { return false }
  if !update(dy, rect.ury - start.y) { return false }
  if t1 < 0.0 || t0 > 1.0 {
    return false
  }
  let min_t = if t0 < 0.0 { 0.0 } else { t0 }
  let max_t = if t1 > 1.0 { 1.0 } else { t1 }
  if max_t <= eps || min_t >= 1.0 - eps {
    return false
  }
  true
}

///|
fn simplify_polyline(
  points : Array[@geom.Point],
  tol : Double,
) -> Array[@geom.Point] {
  if tol <= 0.0 || points.length() <= 2 {
    return points
  }
  let last = points.length() - 1
  let keep = Array::make(points.length(), false)
  keep[0] = true
  keep[last] = true
  let stack : Array[(Int, Int)] = []
  stack.push((0, last))
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (start, end) = stack[top]
    let _ = stack.pop()
    if end - start <= 1 {
      continue
    }
    let mut max_dist = -1.0
    let mut max_idx = -1
    let start_point = points[start]
    let end_point = points[end]
    for i in (start + 1)..<end {
      let dist = curve_point_line_distance(points[i], start_point, end_point)
      if dist > max_dist {
        max_dist = dist
        max_idx = i
      }
    }
    if max_idx != -1 && max_dist > tol {
      keep[max_idx] = true
      stack.push((start, max_idx))
      stack.push((max_idx, end))
    }
  }
  let out : Array[@geom.Point] = []
  for i in 0..<points.length() {
    if keep[i] {
      out.push(points[i])
    }
  }
  out
}

///|
const DEFAULT_VNODE_WEIGHT : Double = 1.0

///|
priv struct EdgePolylinePointsInput {
  edge : @cgraph.Edge
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnode_positions : Map[String, @geom.Point]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  nodesep_pt : Double
  label_width_pt : Double
  label_height_pt : Double?
  dotted_weight : Double
  use_cluster_tuning : Bool
  split_label : Bool
  same_local_cluster : Bool
  default_vnode_weight : Double
}

///|
fn edge_polyline_points(
  input : EdgePolylinePointsInput,
) -> Array[@geom.Point] {
  let edge = input.edge
  let tail_name = input.tail_name
  let head_name = input.head_name
  let tail_port = input.tail_port
  let head_port = input.head_port
  let tail_anchor = input.tail_anchor
  let head_anchor = input.head_anchor
  let ranks = input.ranks
  let edge_vnodes = input.edge_vnodes
  let vnode_ranks = input.vnode_ranks
  let vnode_positions = input.vnode_positions
  let rank_y = input.rank_y
  let rank_ht1 = input.rank_ht1
  let nodesep_pt = input.nodesep_pt
  let label_width_pt = input.label_width_pt
  let label_height_pt = input.label_height_pt
  let dotted_weight = input.dotted_weight
  let use_cluster_tuning = input.use_cluster_tuning
  let split_label = input.split_label
  let same_local_cluster = input.same_local_cluster
  let default_vnode_weight = input.default_vnode_weight
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
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
            @edge_identity.port_is_explicit(tail_port) || @edge_identity.port_is_explicit(head_port)
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
  let label_height_pt =
    if input.base.mid_label_height_pt > 0.0 {
      Some(input.base.mid_label_height_pt)
    } else {
      None
    }
  let has_explicit_port =
    @edge_identity.port_is_explicit(input.base.tail_port) ||
    @edge_identity.port_is_explicit(input.base.head_port)
  let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
  let split_label = input.enable_complex_tuning &&
    label_width_pt > 0.0 &&
    input.base.same_outer_cluster &&
    input.base.diff_local_cluster &&
    abs_dx > label_width_pt
  let label_pad_boost = if split_label { input.nodesep_pt * 1.2 } else { 0.0 }
  let dotted_weight = if input.enable_complex_tuning { 1.0 } else { 0.8 }
  let guide_points =
    edge_polyline_points(
      {
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
      },
    )
  let route_state =
    compute_pathplan_route_points(
      {
        base: input.base,
        ranks: input.ranks,
        positions: input.positions,
        vnode_positions: input.vnode_positions,
        vnode_info: input.vnode_info,
        sizes: input.sizes,
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
      },
    )
  let using_pathplan = route_state.using_pathplan
  let points =
    adjust_route_points(
      {
        points: route_state.points,
        base: input.base,
        head_port_rect: input.base.head_port_rect,
        has_explicit_port,
        using_pathplan,
        nodesep_pt: input.nodesep_pt,
      },
    )
  let curve_offset_params = compute_curve_offset(
    {
      edge,
      base: input.base,
      head_port_metrics: input.head_port_metrics,
      label_width_pt,
      nodesep_pt: input.nodesep_pt,
      enable_complex_tuning: input.enable_complex_tuning,
    },
  )
  let short_route_context =
    short_route_build_context(
      {
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
      },
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
priv struct AdjustedCurveModePointsInput {
  base : EdgeRouteBase
  prepared : CurveModeRoutePrep
  label_edge_counts : Map[String, Int]
  nodesep_pt : Double
  enable_complex_tuning : Bool
}

///|
fn adjusted_curve_mode_points(
  input : AdjustedCurveModePointsInput,
) -> Array[@geom.Point] {
  let base = input.base
  let prepared = input.prepared
  let label_edge_counts = input.label_edge_counts
  let nodesep_pt = input.nodesep_pt
  let enable_complex_tuning = input.enable_complex_tuning
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
    let adjusted =
      adjusted_curve_mode_points(
        {
          base,
          prepared,
          label_edge_counts,
          nodesep_pt,
          enable_complex_tuning,
        },
      )
    if adjusted.length() <= 2 {
      let short_route_spec =
        short_route_spec_for_adjusted_points(adjusted)
      curve_mode_result_for_short_route(base, prepared, short_route_spec)
    } else {
      let multi_point_spline =
        build_multi_point_routed_spline(
          {
            base,
            adjusted,
            using_pathplan: prepared.using_pathplan,
            force_segmented: base.force_segmented,
            pathplan_segments: prepared.pathplan_segments,
            route_barriers: prepared.route_barriers,
            tail_clip_enabled: base.tail_clip_enabled,
            head_clip_enabled: base.head_clip_enabled,
          },
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
        {
          points,
          using_pathplan: prepared.using_pathplan,
          tail_anchor: base.tail_anchor,
          head_anchor: base.head_anchor,
          tail_clip_enabled: base.tail_clip_enabled,
          head_clip_enabled: base.head_clip_enabled,
        },
      )
    curve_mode_result_for_short_route(base, prepared, short_route_spec)
  }
}

///|
fn build_edge_curve_mode_result(
  input : CurveModeRouteInput,
) -> EdgeSplineResult {
  let prepared =
    prepare_edge_curve_mode_route(
      input,
    )
  let spline_result =
    build_curve_mode_spline_from_prepared_route(
      {
        base: input.base,
        prepared,
        label_edge_counts: input.label_edge_counts,
        nodesep_pt: input.nodesep_pt,
        enable_complex_tuning: input.enable_complex_tuning,
      },
    )
  let (pathplan_boxes, pathplan_segments) =
    finalize_pathplan_boxes_and_segments(
      {
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
pub fn build_edge_spline(
  input : EdgeSplineBuildInput,
) -> EdgeSplineResult {
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
    build_edge_curve_mode_result(
      {
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
        label_edge_counts: input.label_edge_counts,
        head_port_metrics: input.head_port_metrics,
        routing_context: input.routing_context,
        enable_complex_tuning: input.enable_complex_tuning,
      },
    )
  }
}
///|
priv struct RoutePointState {
  points : Array[@geom.Point]
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  pathplan_segments : Array[@routesplines.PathplanSegment]
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
  label_edge_counts : Map[String, Int]
  head_port_metrics : HeadPortMetrics
  routing_context : RoutingContext
  enable_complex_tuning : Bool
}

///|
fn sameport_path_port_box(
  center : @geom.Point,
  anchor : @geom.Point,
  group_size : Int,
) -> @geom.Rect {
  // Graphviz parity: large sameport groups keep a tiny inward port-box offset;
  // this preserves oldarrows/honda routing-label snapshots exactly.
  let (bx, by) =
    if group_size > 3 {
      let dx = anchor.x - center.x
      let dy = anchor.y - center.y
      let len = Double::sqrt(dx * dx + dy * dy)
      if len > 0.0 {
        let offset = 0.005
        (anchor.x - dx / len * offset, anchor.y - dy / len * offset)
      } else {
        (anchor.x, anchor.y)
      }
    } else {
      (anchor.x, anchor.y)
    }
  let eps = if group_size > 3 { 0.005 } else { 0.01 }
  {
    llx: bx - eps,
    lly: by - eps,
    urx: bx + eps,
    ury: by + eps,
  }
}

///|
/// Graphviz parity: pathplan polyline aligned to refs/graphviz/lib/pathplan/* + lib/common/routespl.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
priv struct PathplanRoutePointsInput {
  base : EdgeRouteBase
  ranks : Map[String, Int]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  vnode_info : EdgeVnodeInfo
  sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  path_left_bound : Double
  path_right_bound : Double
  ranksep_pt : Double
  routing_context : RoutingContext
  guide_points : Array[@geom.Point]
}

///|
/// Graphviz parity: pathplan route-point input keeps route geometry/rank maps
/// grouped so pathplan invocation and fallback order remain explicit.
/// Do not change behavior without updating fixtures/tests.
fn compute_pathplan_route_points(
  input : PathplanRoutePointsInput,
) -> RoutePointState {
  let mut route_barriers : Array[(@geom.Point, @geom.Point)] = []
  let mut pathplan_boxes : Array[@geom.Rect] = []
  let mut pathplan_points : Array[@geom.Point] = []
  let mut pathplan_segments : Array[@routesplines.PathplanSegment] = []
  let (points, pathplan_used) =
    if input.base.use_pathplan && !input.base.is_flat_edge {
    let has_edge_label = input.base.mid_label_width_pt > 0.0
    // Graphviz parity: record_path port boxes narrow pathplan bounds (shapes.c).
    let tail_port_box : @geom.Rect? =
      if !input.base.tail_clip_enabled {
        Some(
          sameport_path_port_box(
            input.base.tail_pos,
            input.base.tail_anchor,
            input.base.tail_sameport_group_size,
          ),
        )
      } else if input.base.tail_port_side == 0 {
        input.base.tail_record_path_box
      } else {
        None
      }
    let head_port_box : @geom.Rect? =
      if !input.base.head_clip_enabled {
        Some(
          sameport_path_port_box(
            input.base.head_pos,
            input.base.head_anchor,
            input.base.head_sameport_group_size,
          ),
        )
      } else if input.base.head_port_side == 0 {
        input.base.head_record_path_box
      } else {
        None
      }
    match @routesplines.edge_pathplan_polyline(
      input.base.edge,
      input.base.tail_name,
      input.base.head_name,
      input.base.tail_anchor,
      input.base.head_anchor,
      input.base.layout_rankdir,
      input.base.tail_port_side,
      input.base.head_port_side,
      tail_port_box,
      head_port_box,
      input.ranksep_pt,
      input.ranks,
      input.vnode_info.vnode_ranks,
      input.vnode_info.edge_vnodes,
      input.positions,
      input.vnode_positions,
      input.sizes,
      input.routing_context.pathplan_sizes,
      input.routing_context.pathplan_vnode_mval_sizes,
      input.vnode_info.vnode_sizes,
      input.routing_context.path_cluster_keys,
      input.routing_context.path_vnode_clusters,
      input.routing_context.cluster_bboxes,
      input.x_groups,
      input.routing_context.path_order_index,
      input.routing_context.path_adjacency.out_edges,
      input.routing_context.path_adjacency.in_edges,
      input.rank_y,
      input.rank_ht1,
      input.rank_ht2,
      input.nodesep_pt,
      input.path_left_bound,
      input.path_right_bound,
      has_edge_label,
    ) {
      Some(result) => {
        route_barriers = result.barriers
        pathplan_boxes = result.boxes
        pathplan_points = result.points.copy()
        pathplan_segments = result.segments
        (result.points, true)
      }
      None => (input.guide_points, false)
    }
  } else {
    (
      input.guide_points,
      false,
    )
  }
  {
    points,
    using_pathplan: pathplan_used,
    pathplan_boxes,
    pathplan_points,
    route_barriers,
    pathplan_segments,
  }
}

///|
/// Graphviz parity: route point tweaks aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
priv struct AdjustRoutePointsInput {
  points : Array[@geom.Point]
  base : EdgeRouteBase
  head_port_rect : @geom.Rect?
  has_explicit_port : Bool
  using_pathplan : Bool
  nodesep_pt : Double
}

///|
fn adjust_route_points(
  input : AdjustRoutePointsInput,
) -> Array[@geom.Point] {
  let base = input.base
  let head_port_rect = input.head_port_rect
  let has_explicit_port = input.has_explicit_port
  let using_pathplan = input.using_pathplan
  let nodesep_pt = input.nodesep_pt
  let mut points = input.points
  let touch_eps = max_double(@record_geometry.RECORD_BORDER_PT + 0.01, 1.5)
  let head_lr_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = @edge_spline.port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.llx - node_rect.llx) <= touch_eps ||
          Double::abs(rect.urx - node_rect.urx) <= touch_eps
      }
      None => false
    }
  let head_tb_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = @edge_spline.port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.lly - node_rect.lly) <= touch_eps ||
          Double::abs(rect.ury - node_rect.ury) <= touch_eps
      }
      None => false
    }
  let detour_ok =
    match base.layout_rankdir {
      RankDir::TB | RankDir::BT => head_tb_touch && !head_lr_touch
      RankDir::LR | RankDir::RL => head_lr_touch && !head_tb_touch
    }
  if points.length() <= 2 && has_explicit_port && detour_ok && !using_pathplan {
    let tail_rect = @edge_spline.port_side_rect(base.tail_pos, base.tail_size)
    let head_rect = @edge_spline.port_side_rect(base.head_pos, base.head_size)
    let anchor_eps = 0.02
    let needs_detour =
      segment_intersects_rect(
        base.tail_anchor,
        base.head_anchor,
        head_rect,
        anchor_eps,
      )
    if needs_detour {
      points =
        detour_polyline_for_rects(
          {
            tail: base.tail_anchor,
            head: base.head_anchor,
            tail_rect,
            head_rect,
            nodesep_pt,
            rankdir: base.layout_rankdir,
          },
        )
    }
  }
  if base.is_dotted && !base.same_outer_cluster && !using_pathplan {
    points = @edge_ops.adjust_intercluster_dots(
      points,
      base.tail_anchor,
      base.head_anchor,
      base.head_clip_size,
      nodesep_pt,
    )
  }
  if has_explicit_port && base.has_side_anchor && points.length() <= 2 &&
    !using_pathplan {
    let offset = max_double(4.0, nodesep_pt * 0.5)
    let kinked : Array[@geom.Point] = [base.tail_anchor]
    if base.tail_slope.x != 0.0 || base.tail_slope.y != 0.0 {
      kinked.push(@edge_spline.point_add(base.tail_anchor, @edge_spline.point_scale(base.tail_slope, offset)))
    }
    if base.head_slope.x != 0.0 || base.head_slope.y != 0.0 {
      kinked.push(@edge_spline.point_add(base.head_anchor, @edge_spline.point_scale(base.head_slope, -offset)))
    }
    kinked.push(base.head_anchor)
    points = kinked
  }
  points
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
fn compute_curve_offset(
  input : CurveOffsetInput,
) -> CurveOffsetParams {
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
    let key =
      if head_port_key == "" {
      if @record_geometry.is_record_shape(edge.head()) { base.orig_head_name } else { "" }
    } else {
      "\{base.orig_head_name}:\{head_port_key}"
    }
    if key != "" {
      let count = head_port_metrics.head_port_counts.get(key).unwrap_or_default()
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
              RankDir::TB | RankDir::BT =>
                if dx < 0.0 {
                  curve_skew = 0.5
                }
              RankDir::LR | RankDir::RL =>
                if dy < 0.0 {
                  curve_skew = 0.5
                }
            }
          }
        }
      }
    }
  }
  { curve_offset, curve_skew }
}

