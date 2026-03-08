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
priv struct RoutePointState {
  points : Array[@geom.Point]
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  pathplan_segments : Array[@routesplines.PathplanSegment]
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

