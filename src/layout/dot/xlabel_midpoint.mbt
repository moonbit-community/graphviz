///|
/// Edge anchor and midpoint helpers for exterior-label placement.

///|
const MILLIPOINT : Double = 0.001

priv struct EdgeEndpoints {
  tail : @geom.Point
  head : @geom.Point
}

fn edge_tail_point_for_layout(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
}

fn edge_head_point_for_layout(edge_layout : DotLayoutEdge) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let last_idx = edge_layout.splines.length() - 1
  match edge_layout.splines.get(last_idx) {
    Some(spline) =>
      match spline.end {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 {
            Some(spline.points[spline.points.length() - 1])
          } else {
            None
          }
      }
    None => None
  }
}

fn edge_endpoints(
  edge_layout : DotLayoutEdge,
) -> EdgeEndpoints? {
  match (edge_tail_point_for_layout(edge_layout),
    edge_head_point_for_layout(edge_layout)) {
    (Some(tail), Some(head)) => Some({ tail, head })
    _ => None
  }
}

fn approx_eq_point(a : @geom.Point, b : @geom.Point) -> Bool {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy < MILLIPOINT * MILLIPOINT
}

///|
/// Graphviz parity: closest spline point aligned to refs/graphviz/lib/common/utils.c
/// (dotneato_closest).
/// Do not change behavior without updating fixtures/tests.
fn dotneato_closest_point(
  edge_layout : DotLayoutEdge,
  target : @geom.Point,
) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let mut best_i = 0
  let mut best_j = 0
  let mut best_dist = 1.0e38
  let mut found = false
  for i in 0..<edge_layout.splines.length() {
    let spline = edge_layout.splines[i]
    let points = spline.points
    for j in 0..<points.length() {
      let p = points[j]
      let dx = p.x - target.x
      let dy = p.y - target.y
      let dist = dx * dx + dy * dy
      if !found || dist < best_dist {
        best_dist = dist
        best_i = i
        best_j = j
        found = true
      }
    }
  }
  if !found {
    return None
  }
  let spline = edge_layout.splines[best_i]
  let points = spline.points
  if points.length() == 0 {
    return None
  }
  if points.length() < 4 {
    return Some(points[0])
  }
  let mut closest_idx = best_j
  if closest_idx == points.length() - 1 {
    closest_idx = closest_idx - 1
  }
  let j = 3 * (closest_idx / 3)
  if j + 3 >= points.length() {
    return Some(points[points.length() - 1])
  }
  let p0 = points[j]
  let p1 = points[j + 1]
  let p2 = points[j + 2]
  let p3 = points[j + 3]
  let mut low = 0.0
  let mut high = 1.0
  let mut dlow = {
    let dx = p0.x - target.x
    let dy = p0.y - target.y
    dx * dx + dy * dy
  }
  let mut dhigh = {
    let dx = p3.x - target.x
    let dy = p3.y - target.y
    dx * dx + dy * dy
  }
  let mut pt2 = p0
  while true {
    let t = (low + high) / 2.0
    pt2 = bezier_point_fma(p0, p1, p2, p3, t)
    if Double::abs(dlow - dhigh) < 1.0 {
      break
    }
    if Double::abs(high - low) < 0.00001 {
      break
    }
    if dlow < dhigh {
      high = t
      let dx = pt2.x - target.x
      let dy = pt2.y - target.y
      dhigh = dx * dx + dy * dy
    } else {
      low = t
      let dx = pt2.x - target.x
      let dy = pt2.y - target.y
      dlow = dx * dx + dy * dy
    }
  }
  Some(pt2)
}

fn polyline_midpoint(edge_layout : DotLayoutEdge) -> @geom.Point? {
  if edge_layout.splines.length() == 0 {
    return None
  }
  let mut total = 0.0
  for spline in edge_layout.splines {
    let points = spline.points
    let mut j = 0
    while j + 3 < points.length() {
      total = total + @edge_spline.segment_length(points[j], points[j + 3])
      j = j + 3
    }
  }
  if total <= 0.0 {
    match edge_endpoints(edge_layout) {
      Some(endpoints) => return Some(endpoints.tail)
      None => return None
    }
  }
  let mut dist = total / 2.0
  for spline in edge_layout.splines {
    let points = spline.points
    let mut j = 0
    while j + 3 < points.length() {
      let pf = points[j]
      let qf = points[j + 3]
      let d = @edge_spline.segment_length(pf, qf)
      if d >= dist {
        let t = dist / d
        let x = qf.x * t + pf.x * (1.0 - t)
        let y = qf.y * t + pf.y * (1.0 - t)
        return Some(@edge_spline.point(x, y))
      }
      dist = dist - d
      j = j + 3
    }
  }
  None
}

///|
/// Graphviz parity: edge midpoint selection aligned to refs/graphviz/lib/common/splines.c
/// (edgeMidpoint).
/// Do not change behavior without updating fixtures/tests.
fn edge_midpoint_for_layout(
  edge_layout : DotLayoutEdge,
  splines : SplinesMode,
) -> @geom.Point? {
  match edge_endpoints(edge_layout) {
    Some(endpoints) => {
      if approx_eq_point(endpoints.tail, endpoints.head) {
        return Some(endpoints.tail)
      }
      match splines {
        SplinesMode::Spline | SplinesMode::Curved => {
          let mid =
            @edge_spline.point(
              (endpoints.tail.x + endpoints.head.x) / 2.0,
              (endpoints.tail.y + endpoints.head.y) / 2.0,
            )
          match dotneato_closest_point(edge_layout, mid) {
            Some(value) => Some(value)
            None => Some(mid)
          }
        }
        _ => polyline_midpoint(edge_layout)
      }
    }
    None => None
  }
}
