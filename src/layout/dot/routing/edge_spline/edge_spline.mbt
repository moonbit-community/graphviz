///|
type NodeSize = @node_primitives.NodeSize

///|
type RankDir = @rankdir.RankDir

///|
const RECORD_BORDER_PT : Double = @record_geometry.RECORD_BORDER_PT

///|
const PORT_SIDE_BOTTOM : Int = 1

///|
const PORT_SIDE_RIGHT : Int = 2

///|
const PORT_SIDE_TOP : Int = 4

///|
const PORT_SIDE_LEFT : Int = 8


///|
const BEZIER_CLIP_EPS : Double = 0.5

///|
const POLY_GAP_PT : Double = 4.0

///|
const MILLIPOINT : Double = 0.001

///|
const ARROW_CLIP_EPS : Double = 0.5


///|
priv struct Triangle {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
}

///|
pub fn point(x : Double, y : Double) -> @geom.Point {
  @geom.Point::{ x, y }
}

///|
pub fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x + b.x, a.y + b.y)
}

///|
pub fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x - b.x, a.y - b.y)
}

///|
pub fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  point(a.x * s, a.y * s)
}

///|
pub fn point_dist2(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy
}

///|
///|
priv struct BezierSplitResult {
  point : @geom.Point
  left : Array[@geom.Point]
  right : Array[@geom.Point]
}

///|
///|
pub fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  point_add(a, point_scale(point_sub(b, a), t))
}

///|
///|
fn bezier_split(
  points : Array[@geom.Point],
  t : Double,
) -> BezierSplitResult {
  let p0 = points[0]
  let p1 = points[1]
  let p2 = points[2]
  let p3 = points[3]
  let p01 = point_lerp(p0, p1, t)
  let p12 = point_lerp(p1, p2, t)
  let p23 = point_lerp(p2, p3, t)
  let p012 = point_lerp(p01, p12, t)
  let p123 = point_lerp(p12, p23, t)
  let p0123 = point_lerp(p012, p123, t)
  let left : Array[@geom.Point] = [p0, p01, p012, p0123]
  let right : Array[@geom.Point] = [p0123, p123, p23, p3]
  { point: p0123, left, right }
}

///|
fn bezier_clip(
  points : Array[@geom.Point],
  inside : (@geom.Point) -> Bool,
  left_inside : Bool,
) -> Array[@geom.Point] {
  bezier_clip_eps(points, inside, left_inside, BEZIER_CLIP_EPS)
}

///|
fn bezier_clip_eps(
  points : Array[@geom.Point],
  inside : (@geom.Point) -> Bool,
  left_inside : Bool,
  eps : Double,
) -> Array[@geom.Point] {
  let mut low = 0.0
  let mut high = 1.0
  let mut pt = if left_inside { points[0] } else { points[3] }
  let mut opt = pt
  let mut seg = points
  let mut best = points
  let mut found = false
  while true {
    opt = pt
    let t = (high + low) / 2.0
    let split = bezier_split(points, t)
    pt = split.point
    seg = if left_inside { split.right } else { split.left }
    if inside(pt) {
      if left_inside {
        low = t
      } else {
        high = t
      }
      best = seg
      found = true
    } else if left_inside {
      high = t
    } else {
      low = t
    }
    if Double::abs(opt.x - pt.x) <= eps && Double::abs(opt.y - pt.y) <= eps {
      break
    }
  }
  if found {
    best
  } else {
    seg
  }
}

///|
fn apply_parallel_offset(
  points : Array[@geom.Point],
  offset : Double,
) -> Array[@geom.Point] {
  if offset == 0.0 || points.length() <= 2 {
    return points
  }
  let out = points.copy()
  let mut idx = 1
  let last = out.length() - 1
  while idx < last {
    let p = out[idx]
    out[idx] = { x: p.x + offset, y: p.y }
    idx = idx + 1
  }
  out
}

///|
fn miter_shape(
  base_left : @geom.Point,
  p : @geom.Point,
  base_right : @geom.Point,
  penwidth : Double,
) -> Triangle {
  if (base_left.x == p.x && base_left.y == p.y) ||
    (base_right.x == p.x && base_right.y == p.y) {
    return Triangle::{ p0: p, p1: p, p2: p }
  }
  let dx_a = p.x - base_left.x
  let dy_a = p.y - base_left.y
  let hypot_a = @math.hypot(dx_a, dy_a)
  let cos_alpha = dx_a / hypot_a
  let sin_alpha = dy_a / hypot_a
  let alpha = if dy_a > 0.0 {
    @math.acos(cos_alpha)
  } else {
    -@math.acos(cos_alpha)
  }
  let p1 = point(
    p.x - penwidth / 2.0 * sin_alpha,
    p.y + penwidth / 2.0 * cos_alpha,
  )
  let dx_b = base_right.x - p.x
  let dy_b = base_right.y - p.y
  let hypot_b = @math.hypot(dx_b, dy_b)
  let cos_beta = dx_b / hypot_b
  let beta = if dy_b > 0.0 {
    @math.acos(cos_beta)
  } else {
    -@math.acos(cos_beta)
  }
  let beta_rev = beta - @math.PI
  let mut theta = beta_rev - alpha
  if theta <= -@math.PI {
    theta = theta + 2.0 * @math.PI
  }
  let stroke_miterlimit = 4.0
  let normalized_miter_length = 1.0 / @math.sin(theta / 2.0)
  let sin_beta = dy_b / hypot_b
  let sin_beta_minus_pi = -sin_beta
  let cos_beta_minus_pi = -cos_beta
  let p2 = point(
    p.x + penwidth / 2.0 * sin_beta_minus_pi,
    p.y - penwidth / 2.0 * cos_beta_minus_pi,
  )
  if normalized_miter_length > stroke_miterlimit {
    let p_bevel = point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
    Triangle::{ p0: p_bevel, p1, p2 }
  } else {
    let l = penwidth / 2.0 / @math.tan(theta / 2.0)
    let p3 = point(p1.x + l * cos_alpha, p1.y + l * sin_alpha)
    Triangle::{ p0: p3, p1, p2 }
  }
}

///|
pub fn edge_spline_for_polyline(
  edge : @cgraph.Edge,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  orthogonal : Bool,
  include_tail : Bool,
  include_head : Bool,
  tail_clip_enabled? : Bool = true,
  head_clip_enabled? : Bool = true,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
  parallel_offset? : Double = 0.0,
  clip_swapped? : Bool = false,
  arrow_swapped? : Bool = false,
) -> @geom.Spline {
  let (tail, head) = if tail_clip == head_clip {
    (tail_clip, point(head_clip.x + 1.0, head_clip.y))
  } else {
    (tail_clip, head_clip)
  }
  let raw_points = if orthogonal {
    match orthogonal_polyline_points_cardinal(
      edge,
      tail_clip_center,
      head_clip_center,
      rankdir,
    ) {
      Some(points) => points
      None => orthogonal_polyline_points(tail, head, rankdir)
    }
  } else {
    [tail, head]
  }
  let arrow_lengths =
    if include_tail || include_head {
      arrow_length_for_edge_oriented(
        edge,
        include_tail,
        include_head,
        arrow_len_override,
        arrow_swapped,
      )
    } else {
      { tail: 0.0, head: 0.0 }
    }
  let polyline = compact_polyline(raw_points)
  let bezier_points =
    if orthogonal {
      polyline_to_bezier_make_polyline(compact_polyline(polyline))
    } else {
      polyline_to_bezier(compact_polyline(polyline))
    }
  let bezier = apply_parallel_offset(bezier_points, parallel_offset)
  let clipped =
    clip_spline_to_nodes(
      edge,
      bezier,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_clip_enabled_override=Some(tail_clip_enabled),
      head_clip_enabled_override=Some(head_clip_enabled),
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
      clip_swapped=clip_swapped,
    )
  let trimmed = trim_degenerate_spline_segments(clipped)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped =
    if include_tail || include_head {
    clip_spline_arrows(
      trimmed,
      arrow_lengths.tail,
      arrow_lengths.head,
      include_tail,
      include_head,
      arrow_clip_eps,
      orthogonal=orthogonal,
    )
  } else {
    { points: trimmed, start_point: None, end_point: None }
  }
  let points =
    adjust_tail_cluster_compound_segment(
      arrow_clipped.points,
      arrow_clipped.end_point,
      include_tail,
      include_head,
      tail_cluster_bbox,
    )
  { start: arrow_clipped.start_point, end: arrow_clipped.end_point, points }
}

///|
/// Graphviz parity: edge spline generation aligned to refs/graphviz/lib/common/splines.c + dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn edge_spline_for_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  force_segmented : Bool,
  include_tail : Bool,
  include_head : Bool,
  tail_clip_enabled? : Bool = true,
  head_clip_enabled? : Bool = true,
  tail_port_side? : Int = 0,
  head_port_side? : Int = 0,
  route_barriers? : Array[(@geom.Point, @geom.Point)] = [],
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
  parallel_offset? : Double = 0.0,
  clip_swapped? : Bool = false,
  arrow_swapped? : Bool = false,
) -> @geom.Spline {
  if points.length() == 0 {
    return { start: None, end: None, points: [] }
  }
  let arrow_lengths =
    if include_tail || include_head {
      arrow_length_for_edge_oriented(
        edge,
        include_tail,
        include_head,
        arrow_len_override,
        arrow_swapped,
      )
    } else {
      { tail: 0.0, head: 0.0 }
    }
  let bezier =
    apply_parallel_offset(
      route_bezier_points(
        points,
        tail_slope,
        head_slope,
        force_segmented,
        route_barriers,
      ),
      parallel_offset,
    )
  let spline_points =
    clip_spline_to_nodes(
      edge,
      bezier,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_clip_enabled_override=Some(tail_clip_enabled),
      head_clip_enabled_override=Some(head_clip_enabled),
      tail_port_side=tail_port_side,
      head_port_side=head_port_side,
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
      clip_swapped=clip_swapped,
    )
  let trimmed = trim_degenerate_spline_segments(spline_points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped =
    if include_tail || include_head {
    clip_spline_arrows(
      trimmed,
      arrow_lengths.tail,
      arrow_lengths.head,
      include_tail,
      include_head,
      arrow_clip_eps,
    )
  } else {
    { points: trimmed, start_point: None, end_point: None }
  }
  let clipped =
    adjust_tail_cluster_compound_segment(
      arrow_clipped.points,
      arrow_clipped.end_point,
      include_tail,
      include_head,
      tail_cluster_bbox,
    )
  let mut has_dupes = false
  for i in 1..<clipped.length() {
    if clipped[i] == clipped[i - 1] {
      has_dupes = true
      break
    }
  }
  let points_out = if has_dupes { clipped } else { dedup_consecutive(clipped) }
  {
    start: arrow_clipped.start_point,
    end: arrow_clipped.end_point,
    points: points_out,
  }
}

///|
/// Graphviz parity: spline clipping for precomputed Bézier control points
/// (self-edge paths) aligned to refs/graphviz/lib/common/splines.c.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_spline_for_bezier_points(
  edge : @cgraph.Edge,
  bezier : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  include_tail : Bool,
  include_head : Bool,
  tail_clip_enabled? : Bool = true,
  head_clip_enabled? : Bool = true,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
  parallel_offset? : Double = 0.0,
  clip_swapped? : Bool = false,
  arrow_swapped? : Bool = false,
) -> @geom.Spline {
  if bezier.length() == 0 {
    return { start: None, end: None, points: [] }
  }
  let arrow_lengths =
    if include_tail || include_head {
      arrow_length_for_edge_oriented(
        edge,
        include_tail,
        include_head,
        arrow_len_override,
        arrow_swapped,
      )
    } else {
      { tail: 0.0, head: 0.0 }
    }
  let bezier_points =
    if parallel_offset != 0.0 {
    apply_parallel_offset(bezier, parallel_offset)
  } else {
    bezier
  }
  let spline_points =
    clip_spline_to_nodes(
      edge,
      bezier_points,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_clip_enabled_override=Some(tail_clip_enabled),
      head_clip_enabled_override=Some(head_clip_enabled),
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
      clip_swapped=clip_swapped,
    )
  let trimmed = trim_degenerate_spline_segments(spline_points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped =
    if include_tail || include_head {
    clip_spline_arrows(
      trimmed,
      arrow_lengths.tail,
      arrow_lengths.head,
      include_tail,
      include_head,
      arrow_clip_eps,
    )
  } else {
    { points: trimmed, start_point: None, end_point: None }
  }
  let clipped =
    adjust_tail_cluster_compound_segment(
      arrow_clipped.points,
      arrow_clipped.end_point,
      include_tail,
      include_head,
      tail_cluster_bbox,
    )
  let mut has_dupes = false
  for i in 1..<clipped.length() {
    if clipped[i] == clipped[i - 1] {
      has_dupes = true
      break
    }
  }
  let points_out = if has_dupes { clipped } else { dedup_consecutive(clipped) }
  {
    start: arrow_clipped.start_point,
    end: arrow_clipped.end_point,
    points: points_out,
  }
}

///|
pub fn edge_spline_raw_for_points(
  points : Array[@geom.Point],
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  force_segmented : Bool,
  route_barriers? : Array[(@geom.Point, @geom.Point)] = [],
) -> Array[@geom.Point] {
  route_bezier_points(
    points,
    tail_slope,
    head_slope,
    force_segmented,
    route_barriers,
  )
}

///|

///|
pub fn edge_spline_raw_for_line(
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  rankdir : RankDir,
  curve_offset : Double,
  curve_skew : Double,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> Array[@geom.Point] {
  line_bezier_points(
    tail_center,
    head_center,
    tail_slope,
    head_slope,
    rankdir,
    curve_offset,
    curve_skew,
    tail_cluster_bbox,
    head_cluster_bbox,
    false,
  )
}

///|
pub fn edge_spline_for_line(
  edge : @cgraph.Edge,
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  include_tail : Bool,
  include_head : Bool,
  tail_clip_enabled? : Bool = true,
  head_clip_enabled? : Bool = true,
  rankdir : RankDir,
  curve_offset : Double,
  curve_skew : Double,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
  prefer_linear? : Bool = false,
  parallel_offset? : Double = 0.0,
  clip_swapped? : Bool = false,
  arrow_swapped? : Bool = false,
) -> @geom.Spline {
  let arrow_lengths =
    if include_tail || include_head {
      arrow_length_for_edge_oriented(
        edge,
        include_tail,
        include_head,
        arrow_len_override,
        arrow_swapped,
      )
    } else {
      { tail: 0.0, head: 0.0 }
    }
  let mut points =
    line_bezier_points(
      tail_center,
      head_center,
      tail_slope,
      head_slope,
      rankdir,
      curve_offset,
      curve_skew,
      tail_cluster_bbox,
      head_cluster_bbox,
      prefer_linear,
    )
  let has_mid_label = match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
  if !has_mid_label &&
    points.length() == 4 &&
    points[0] == points[1] &&
    points[2] == points[3] {
    points = linear_bezier(points[0], points[3])
  }
  points = apply_parallel_offset(points, parallel_offset)
  points =
    clip_spline_to_nodes(
      edge,
      points,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_clip_enabled_override=Some(tail_clip_enabled),
      head_clip_enabled_override=Some(head_clip_enabled),
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
      clip_swapped=clip_swapped,
    )
  points = trim_degenerate_spline_segments(points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped =
    if include_tail || include_head {
      clip_spline_arrows(
        points,
        arrow_lengths.tail,
        arrow_lengths.head,
        include_tail,
        include_head,
        arrow_clip_eps,
      )
    } else {
      { points, start_point: None, end_point: None }
    }
  points =
    adjust_tail_cluster_compound_segment(
      arrow_clipped.points,
      arrow_clipped.end_point,
      include_tail,
      include_head,
      tail_cluster_bbox,
    )
  {
    start: arrow_clipped.start_point,
    end: arrow_clipped.end_point,
    points,
  }
}
