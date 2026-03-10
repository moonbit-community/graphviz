///|
/// Edge spline assembly owner: route fitted or line-derived Bezier points
/// through clipping, arrow trimming, and final spline output assembly.

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
    match
      orthogonal_polyline_points_cardinal(
        edge, tail_clip_center, head_clip_center, rankdir,
      ) {
      Some(points) => points
      None => orthogonal_polyline_points(tail, head, rankdir)
    }
  } else {
    [tail, head]
  }
  let arrow_lengths = if include_tail || include_head {
    arrow_length_for_edge_oriented(
      edge, include_tail, include_head, arrow_len_override, arrow_swapped,
    )
  } else {
    { tail: 0.0, head: 0.0 }
  }
  let polyline = compact_polyline(raw_points)
  let bezier_points = if orthogonal {
    polyline_to_bezier_make_polyline(compact_polyline(polyline))
  } else {
    polyline_to_bezier(compact_polyline(polyline))
  }
  let bezier = apply_parallel_offset(bezier_points, parallel_offset)
  let clipped = clip_spline_to_nodes(
    edge,
    bezier,
    tail_clip_center,
    tail_anchor_size,
    head_clip_center,
    head_anchor_size,
    tail_clip_enabled_override=Some(tail_clip_enabled),
    head_clip_enabled_override=Some(head_clip_enabled),
    tail_cluster_bbox~,
    head_cluster_bbox~,
    clip_swapped~,
  )
  let trimmed = trim_degenerate_spline_segments(clipped)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped = if include_tail || include_head {
    clip_spline_arrows(
      trimmed,
      arrow_lengths.tail,
      arrow_lengths.head,
      include_tail,
      include_head,
      arrow_clip_eps,
      orthogonal~,
    )
  } else {
    { points: trimmed, start_point: None, end_point: None }
  }
  let points = adjust_tail_cluster_compound_segment(
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
  let arrow_lengths = if include_tail || include_head {
    arrow_length_for_edge_oriented(
      edge, include_tail, include_head, arrow_len_override, arrow_swapped,
    )
  } else {
    { tail: 0.0, head: 0.0 }
  }
  let bezier = apply_parallel_offset(
    route_bezier_points(
      points, tail_slope, head_slope, force_segmented, route_barriers,
    ),
    parallel_offset,
  )
  let spline_points = clip_spline_to_nodes(
    edge,
    bezier,
    tail_clip_center,
    tail_anchor_size,
    head_clip_center,
    head_anchor_size,
    tail_clip_enabled_override=Some(tail_clip_enabled),
    head_clip_enabled_override=Some(head_clip_enabled),
    tail_port_side~,
    head_port_side~,
    tail_cluster_bbox~,
    head_cluster_bbox~,
    clip_swapped~,
  )
  let trimmed = trim_degenerate_spline_segments(spline_points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped = if include_tail || include_head {
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
  let clipped = adjust_tail_cluster_compound_segment(
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
  let arrow_lengths = if include_tail || include_head {
    arrow_length_for_edge_oriented(
      edge, include_tail, include_head, arrow_len_override, arrow_swapped,
    )
  } else {
    { tail: 0.0, head: 0.0 }
  }
  let bezier_points = if parallel_offset != 0.0 {
    apply_parallel_offset(bezier, parallel_offset)
  } else {
    bezier
  }
  let spline_points = clip_spline_to_nodes(
    edge,
    bezier_points,
    tail_clip_center,
    tail_anchor_size,
    head_clip_center,
    head_anchor_size,
    tail_clip_enabled_override=Some(tail_clip_enabled),
    head_clip_enabled_override=Some(head_clip_enabled),
    tail_cluster_bbox~,
    head_cluster_bbox~,
    clip_swapped~,
  )
  let trimmed = trim_degenerate_spline_segments(spline_points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped = if include_tail || include_head {
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
  let clipped = adjust_tail_cluster_compound_segment(
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
    points, tail_slope, head_slope, force_segmented, route_barriers,
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
    tail_center, head_center, tail_slope, head_slope, rankdir, curve_offset, curve_skew,
    tail_cluster_bbox, head_cluster_bbox, false,
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
  let arrow_lengths = if include_tail || include_head {
    arrow_length_for_edge_oriented(
      edge, include_tail, include_head, arrow_len_override, arrow_swapped,
    )
  } else {
    { tail: 0.0, head: 0.0 }
  }
  let mut points = line_bezier_points(
    tail_center, head_center, tail_slope, head_slope, rankdir, curve_offset, curve_skew,
    tail_cluster_bbox, head_cluster_bbox, prefer_linear,
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
  points = clip_spline_to_nodes(
    edge,
    points,
    tail_clip_center,
    tail_anchor_size,
    head_clip_center,
    head_anchor_size,
    tail_clip_enabled_override=Some(tail_clip_enabled),
    head_clip_enabled_override=Some(head_clip_enabled),
    tail_cluster_bbox~,
    head_cluster_bbox~,
    clip_swapped~,
  )
  points = trim_degenerate_spline_segments(points)
  // Graphviz parity: arrow clip epsilon is constant across cluster routing.
  let arrow_clip_eps = ARROW_CLIP_EPS
  let arrow_clipped = if include_tail || include_head {
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
  points = adjust_tail_cluster_compound_segment(
    arrow_clipped.points,
    arrow_clipped.end_point,
    include_tail,
    include_head,
    tail_cluster_bbox,
  )
  { start: arrow_clipped.start_point, end: arrow_clipped.end_point, points }
}
