///|
/// Spline bounding-box helpers used by layout bbox aggregation.

///|
/// Graphviz parity: spline bbox uses update_bb_bz refinement aligned to
/// refs/graphviz/lib/common/emit.c (update_bb_bz).
/// Do not change behavior without updating fixtures/tests.
fn spline_bbox(points : Array[@geom.Point]) -> @geom.Rect? {
  if points.length() == 0 {
    return None
  }
  if points.length() % 3 != 1 {
    let mut min_x = points[0].x
    let mut max_x = points[0].x
    let mut min_y = points[0].y
    let mut max_y = points[0].y
    for p in points {
      if p.x < min_x { min_x = p.x }
      if p.x > max_x { max_x = p.x }
      if p.y < min_y { min_y = p.y }
      if p.y > max_y { max_y = p.y }
    }
    return Some({ llx: min_x, lly: min_y, urx: max_x, ury: max_y })
  }
  let mut bbox : @geom.Rect = {
    llx: points[0].x,
    lly: points[0].y,
    urx: points[0].x,
    ury: points[0].y,
  }
  let mut i = 0
  while i + 3 < points.length() {
    let p0 = points[i]
    let p1 = points[i + 1]
    let p2 = points[i + 2]
    let p3 = points[i + 3]
    bbox = update_bbox_with_bezier(bbox, p0, p1, p2, p3)
    i = i + 3
  }
  Some(bbox)
}

fn expand_bbox_with_point(bbox : @geom.Rect, p : @geom.Point) -> @geom.Rect {
  {
    llx: if p.x < bbox.llx { p.x } else { bbox.llx },
    lly: if p.y < bbox.lly { p.y } else { bbox.lly },
    urx: if p.x > bbox.urx { p.x } else { bbox.urx },
    ury: if p.y > bbox.ury { p.y } else { bbox.ury },
  }
}

fn pt_to_line2(a : @geom.Point, b : @geom.Point, p : @geom.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let a2 = (p.y - a.y) * dx - (p.x - a.x) * dy
  let a2_sq = a2 * a2
  if a2_sq < 0.0000000001 {
    0.0
  } else {
    let denom = dx * dx + dy * dy
    if denom == 0.0 { 0.0 } else { a2_sq / denom }
  }
}

fn bezier_controls_near_line(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> Bool {
  let hw = 2.0
  let dis1 = pt_to_line2(p0, p3, p1)
  let dis2 = pt_to_line2(p0, p3, p2)
  dis1 < hw * hw && dis2 < hw * hw
}

priv struct CubicBezierSegment {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
  p3 : @geom.Point
}

priv struct SplitBezierHalf {
  left : CubicBezierSegment
  right : CubicBezierSegment
}

fn split_bezier_half(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> SplitBezierHalf {
  let p01 = @edge_spline.point((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0)
  let p12 = @edge_spline.point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
  let p23 = @edge_spline.point((p2.x + p3.x) / 2.0, (p2.y + p3.y) / 2.0)
  let p012 = @edge_spline.point((p01.x + p12.x) / 2.0, (p01.y + p12.y) / 2.0)
  let p123 = @edge_spline.point((p12.x + p23.x) / 2.0, (p12.y + p23.y) / 2.0)
  let p0123 = @edge_spline.point((p012.x + p123.x) / 2.0, (p012.y + p123.y) / 2.0)
  {
    left: { p0, p1: p01, p2: p012, p3: p0123 },
    right: { p0: p0123, p1: p123, p2: p23, p3 },
  }
}

fn update_bbox_with_bezier(
  bbox : @geom.Rect,
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
) -> @geom.Rect {
  let mut out = bbox
  if p0.x > out.urx || p0.x < out.llx || p0.y > out.ury || p0.y < out.lly ||
    p1.x > out.urx || p1.x < out.llx || p1.y > out.ury || p1.y < out.lly ||
    p2.x > out.urx || p2.x < out.llx || p2.y > out.ury || p2.y < out.lly ||
    p3.x > out.urx || p3.x < out.llx || p3.y > out.ury || p3.y < out.lly {
    if bezier_controls_near_line(p0, p1, p2, p3) {
      out = expand_bbox_with_point(out, p0)
      out = expand_bbox_with_point(out, p1)
      out = expand_bbox_with_point(out, p2)
      out = expand_bbox_with_point(out, p3)
    } else {
      let split = split_bezier_half(p0, p1, p2, p3)
      let left =
        update_bbox_with_bezier(
          out,
          split.left.p0,
          split.left.p1,
          split.left.p2,
          split.left.p3,
        )
      out =
        update_bbox_with_bezier(
          left,
          split.right.p0,
          split.right.p1,
          split.right.p2,
          split.right.p3,
        )
    }
  }
  out
}
