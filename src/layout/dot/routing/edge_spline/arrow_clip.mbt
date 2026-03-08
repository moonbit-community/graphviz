///|
/// Arrow spline clipping owner: trim degenerate Bezier segments and clip
/// spline endpoints so installed arrow markers do not overlap the curve.

fn approx_eq_point(a : @geom.Point, b : @geom.Point, eps : Double) -> Bool {
  Double::abs(a.x - b.x) <= eps && Double::abs(a.y - b.y) <= eps
}

///|
/// Graphviz parity: trim degenerate spline segments before arrow clipping
/// (splines.c clip_and_install).
fn trim_degenerate_spline_segments(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  let mut start = 0
  let mut end = points.length() - 4
  while start < points.length() - 4 &&
    approx_eq_point(points[start], points[start + 3], MILLIPOINT) {
    start += 3
  }
  while end > 0 && approx_eq_point(points[end], points[end + 3], MILLIPOINT) {
    end -= 3
  }
  if start == 0 && end == points.length() - 4 {
    return points
  }
  if end < start {
    end = start
  }
  let out : Array[@geom.Point] = []
  let mut idx = start
  let limit = end + 4
  while idx < limit {
    out.push(points[idx])
    idx += 1
  }
  out
}

priv struct SegmentClipResult {
  points : Array[@geom.Point]
  idx : Int
  anchor : @geom.Point
}

priv struct SplineArrowClipResult {
  points : Array[@geom.Point]
  start_point : @geom.Point?
  end_point : @geom.Point?
}

///|
fn arrow_clip_start_segment(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
  start_idx : Int,
  end_idx : Int,
) -> SegmentClipResult {
  let start_point = points[start_idx]
  if arrow_len <= 0.0 || points.length() < 4 {
    return { points, idx: start_idx, anchor: start_point }
  }
  let len2 = arrow_len * arrow_len
  let mut start = start_idx
  if end_idx > start_idx && point_dist2(points[start], points[start + 3]) < len2 {
    start += 3
  }
  let segment : Array[@geom.Point] = [
    points[start],
    points[start + 1],
    points[start + 2],
    points[start + 3],
  ]
  let clipped = arrow_start_clip(segment, arrow_len, eps, start_point)
  let out = points.copy()
  out[start] = clipped.points[0]
  out[start + 1] = clipped.points[1]
  out[start + 2] = clipped.points[2]
  out[start + 3] = clipped.points[3]
  { points: out, idx: start, anchor: start_point }
}

///|
fn arrow_clip_end_segment(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
  start_idx : Int,
  end_idx : Int,
) -> SegmentClipResult {
  let end_point = points[end_idx + 3]
  if arrow_len <= 0.0 || points.length() < 4 {
    return { points, idx: end_idx, anchor: end_point }
  }
  let len2 = arrow_len * arrow_len
  let mut end = end_idx
  if end > start_idx && point_dist2(points[end], points[end + 3]) < len2 {
    end -= 3
  }
  let segment : Array[@geom.Point] = [
    points[end],
    points[end + 1],
    points[end + 2],
    points[end + 3],
  ]
  let clipped = arrow_end_clip(segment, arrow_len, eps, end_point)
  let out = points.copy()
  out[end] = clipped.points[0]
  out[end + 1] = clipped.points[1]
  out[end + 2] = clipped.points[2]
  out[end + 3] = clipped.points[3]
  { points: out, idx: end, anchor: end_point }
}

///|
fn clip_spline_arrows_ortho(
  points : Array[@geom.Point],
  tail_len : Double,
  head_len : Double,
  include_tail : Bool,
  include_head : Bool,
) -> SplineArrowClipResult {
  let out = points.copy()
  let start_idx = 0
  let end_idx = out.length() - 4
  let mut start_point : @geom.Point? = None
  let mut end_point : @geom.Point? = None
  if include_tail {
    start_point = Some(out[start_idx])
  }
  if include_head {
    end_point = Some(out[end_idx + 3])
  }
  if include_tail && include_head && end_idx == start_idx {
    let p = out[end_idx]
    let q = out[end_idx + 3]
    let mut tlen = tail_len
    let mut hlen = head_len
    let d = point_dist(p, q)
    if hlen + tlen >= d {
      hlen = d / 3.0
      tlen = d / 3.0
    }
    let mut s = p
    let mut t = q
    if p.y == q.y {
      let y = p.y
      s = point(if p.x < q.x { p.x + tlen } else { p.x - tlen }, y)
      t = point(if p.x < q.x { q.x - hlen } else { q.x + hlen }, y)
    } else {
      let x = p.x
      s = point(x, if p.y < q.y { p.y + tlen } else { p.y - tlen })
      t = point(x, if p.y < q.y { q.y - hlen } else { q.y + hlen })
    }
    out[end_idx] = s
    out[end_idx + 1] = s
    out[end_idx + 2] = t
    out[end_idx + 3] = t
    return { points: out, start_point, end_point }
  }
  if include_head {
    let p = out[end_idx]
    let q = out[end_idx + 3]
    let d = point_dist(p, q)
    let maxd = 0.9 * d
    let mut hlen = head_len
    if hlen >= maxd {
      hlen = maxd
    }
    let r = if p.y == q.y {
      point(if p.x < q.x { q.x - hlen } else { q.x + hlen }, p.y)
    } else {
      point(p.x, if p.y < q.y { q.y - hlen } else { q.y + hlen })
    }
    out[end_idx + 1] = p
    out[end_idx + 2] = r
    out[end_idx + 3] = r
  }
  if include_tail {
    let p = out[start_idx]
    let q = out[start_idx + 3]
    let d = point_dist(p, q)
    let maxd = 0.9 * d
    let mut tlen = tail_len
    if tlen >= maxd {
      tlen = maxd
    }
    let r = if p.y == q.y {
      point(if p.x < q.x { p.x + tlen } else { p.x - tlen }, p.y)
    } else {
      point(p.x, if p.y < q.y { p.y + tlen } else { p.y - tlen })
    }
    out[start_idx] = r
    out[start_idx + 1] = r
    out[start_idx + 2] = q
  }
  { points: out, start_point, end_point }
}

///|
fn clip_spline_arrows(
  points : Array[@geom.Point],
  tail_len : Double,
  head_len : Double,
  include_tail : Bool,
  include_head : Bool,
  eps : Double,
  orthogonal? : Bool = false,
) -> SplineArrowClipResult {
  if orthogonal {
    return clip_spline_arrows_ortho(
      points,
      tail_len,
      head_len,
      include_tail,
      include_head,
    )
  }
  let mut out = points
  let mut start_idx = 0
  let mut end_idx = out.length() - 4
  let mut start_point : @geom.Point? = None
  let mut end_point : @geom.Point? = None
  if include_tail {
    let start_clip =
      arrow_clip_start_segment(out, tail_len, eps, start_idx, end_idx)
    out = start_clip.points
    start_idx = start_clip.idx
    start_point = Some(start_clip.anchor)
  }
  if include_head {
    let end_clip =
      arrow_clip_end_segment(out, head_len, eps, start_idx, end_idx)
    out = end_clip.points
    end_idx = end_clip.idx
    end_point = Some(end_clip.anchor)
  }
  if start_idx > 0 || end_idx < out.length() - 4 {
    let trimmed : Array[@geom.Point] = []
    let mut idx = start_idx
    let limit = end_idx + 4
    while idx < limit {
      trimmed.push(out[idx])
      idx += 1
    }
    { points: trimmed, start_point, end_point }
  } else {
    { points: out, start_point, end_point }
  }
}

///|
priv struct ArrowClipResult {
  points : Array[@geom.Point]
}

///|
fn arrow_end_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
  end_point : @geom.Point,
) -> ArrowClipResult {
  if arrow_len <= 0.0 {
    return { points, }
  }
  let sp = [end_point, points[2], points[1], points[0]]
  let len2 = arrow_len * arrow_len
  let clipped =
    bezier_clip_eps(sp, p => point_dist2(p, end_point) <= len2, true, eps)
  let new_points : Array[@geom.Point] = [
    clipped[3],
    clipped[2],
    clipped[1],
    clipped[0],
  ]
  { points: new_points }
}

///|
fn arrow_start_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
  start_point : @geom.Point,
) -> ArrowClipResult {
  if arrow_len <= 0.0 {
    return { points, }
  }
  let sp = [points[3], points[2], points[1], start_point]
  let len2 = arrow_len * arrow_len
  let clipped =
    bezier_clip_eps(sp, p => point_dist2(p, start_point) <= len2, false, eps)
  let new_points : Array[@geom.Point] = [
    clipped[3],
    clipped[2],
    clipped[1],
    clipped[0],
  ]
  { points: new_points }
}
