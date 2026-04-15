// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Routesplines pathplan-route owner: corridor polygon conversion, route
/// solving through boxes, and spline box limiting.
priv struct PathplanRouteResult {
  points : Array[@geom.Point]
  polygon : Array[@geom.Point]
  boxes : Array[@geom.Rect]
}

///|
fn box_overlap(i0 : Double, i1 : Double, j0 : Double, j1 : Double) -> Double {
  if i1 <= j0 || i0 >= j1 {
    return 0.0
  }
  if i0 <= j0 && i1 >= j1 {
    return i1 - i0
  }
  if j0 <= i0 && j1 >= i1 {
    return j1 - j0
  }
  if j0 <= i0 && i0 <= j1 {
    return j1 - i0
  }
  i1 - j0
}

///|
fn sanitize_path_boxes(
  boxes : Array[@geom.Rect],
  start : @geom.Point,
  end : @geom.Point,
) -> (Array[@geom.Rect], @geom.Point, @geom.Point)? {
  let sanitized : Array[@geom.Rect] = []
  for box in boxes {
    if Double::abs(box.lly - box.ury) < 0.01 {
      continue
    }
    if Double::abs(box.llx - box.urx) < 0.01 {
      continue
    }
    sanitized.push(box)
  }
  if sanitized.length() == 0 {
    return None
  }
  let clamp = (value : Double, min_value : Double, max_value : Double) => {
    if value < min_value {
      min_value
    } else if value > max_value {
      max_value
    } else {
      value
    }
  }
  let repaired = sanitized.copy()
  let mut bi = 0
  while bi + 1 < repaired.length() {
    let mut left = repaired[bi]
    let mut right = repaired[bi + 1]
    let l = left.urx < right.llx
    let r = left.llx > right.urx
    let d = left.ury < right.lly
    let u = left.lly > right.ury
    let mut errs = 0
    if l {
      errs = errs + 1
    }
    if r {
      errs = errs + 1
    }
    if d {
      errs = errs + 1
    }
    if u {
      errs = errs + 1
    }
    let mut l_fix = l
    let mut r_fix = r
    let mut d_fix = d
    let mut u_fix = u
    if errs > 0 {
      if l_fix {
        let xy = left.urx
        left = { llx: left.llx, lly: left.lly, urx: right.llx, ury: left.ury }
        right = { llx: xy, lly: right.lly, urx: right.urx, ury: right.ury }
        l_fix = false
      } else if r_fix {
        let xy = left.llx
        left = { llx: right.urx, lly: left.lly, urx: left.urx, ury: left.ury }
        right = { llx: right.llx, lly: right.lly, urx: xy, ury: right.ury }
        r_fix = false
      } else if d_fix {
        let xy = left.ury
        left = { llx: left.llx, lly: left.lly, urx: left.urx, ury: right.lly }
        right = { llx: right.llx, lly: xy, urx: right.urx, ury: right.ury }
        d_fix = false
      } else if u_fix {
        let xy = left.lly
        left = { llx: left.llx, lly: right.ury, urx: left.urx, ury: left.ury }
        right = { llx: right.llx, lly: right.lly, urx: right.urx, ury: xy }
        u_fix = false
      }
      let mut j = 0
      while j < errs - 1 {
        if l_fix {
          let xy = (left.urx + right.llx) / 2.0 + 0.5
          left = { llx: left.llx, lly: left.lly, urx: xy, ury: left.ury }
          right = { llx: xy, lly: right.lly, urx: right.urx, ury: right.ury }
          l_fix = false
        } else if r_fix {
          let xy = (left.llx + right.urx) / 2.0 + 0.5
          left = { llx: xy, lly: left.lly, urx: left.urx, ury: left.ury }
          right = { llx: right.llx, lly: right.lly, urx: xy, ury: right.ury }
          r_fix = false
        } else if d_fix {
          let xy = (left.ury + right.lly) / 2.0 + 0.5
          left = { llx: left.llx, lly: left.lly, urx: left.urx, ury: xy }
          right = { llx: right.llx, lly: xy, urx: right.urx, ury: right.ury }
          d_fix = false
        } else if u_fix {
          let xy = (left.lly + right.ury) / 2.0 + 0.5
          left = { llx: left.llx, lly: xy, urx: left.urx, ury: left.ury }
          right = { llx: right.llx, lly: right.lly, urx: right.urx, ury: xy }
          u_fix = false
        }
        j = j + 1
      }
    }
    let xoverlap = box_overlap(left.llx, left.urx, right.llx, right.urx)
    let yoverlap = box_overlap(left.lly, left.ury, right.lly, right.ury)
    if xoverlap > 0.0 && yoverlap > 0.0 {
      if xoverlap < yoverlap {
        if left.urx - left.llx > right.urx - right.llx {
          left = if left.urx < right.urx {
            { llx: left.llx, lly: left.lly, urx: right.llx, ury: left.ury }
          } else {
            { llx: right.urx, lly: left.lly, urx: left.urx, ury: left.ury }
          }
        } else {
          right = if left.urx < right.urx {
            { llx: left.urx, lly: right.lly, urx: right.urx, ury: right.ury }
          } else {
            { llx: right.llx, lly: right.lly, urx: left.llx, ury: right.ury }
          }
        }
      } else if left.ury - left.lly > right.ury - right.lly {
        left = if left.ury < right.ury {
          { llx: left.llx, lly: left.lly, urx: left.urx, ury: right.lly }
        } else {
          { llx: left.llx, lly: right.ury, urx: left.urx, ury: left.ury }
        }
      } else {
        right = if left.ury < right.ury {
          { llx: right.llx, lly: left.ury, urx: right.urx, ury: right.ury }
        } else {
          { llx: right.llx, lly: right.lly, urx: right.urx, ury: left.lly }
        }
      }
    }
    repaired[bi] = left
    repaired[bi + 1] = right
    bi = bi + 1
  }
  let first = repaired[0]
  let last = repaired[repaired.length() - 1]
  let clamped_start : @geom.Point = {
    x: clamp(start.x, first.llx, first.urx),
    y: clamp(start.y, first.lly, first.ury),
  }
  let clamped_end : @geom.Point = {
    x: clamp(end.x, last.llx, last.urx),
    y: clamp(end.y, last.lly, last.ury),
  }
  Some((repaired, clamped_start, clamped_end))
}

///|
fn boxes_to_polygon_points(boxes : Array[@geom.Rect]) -> Array[@geom.Point] {
  if boxes.length() == 0 {
    return []
  }
  let mut boxes = boxes
  if boxes.length() > 0 {
    let filtered : Array[@geom.Rect] = []
    for box in boxes {
      if Double::abs(box.lly - box.ury) < 0.01 {
        continue
      }
      if Double::abs(box.llx - box.urx) < 0.01 {
        continue
      }
      filtered.push(box)
    }
    boxes = filtered
    if boxes.length() == 0 {
      return []
    }
  }
  let mut flip = false
  let mut boxes_copy = boxes
  if boxes.length() > 1 && boxes[0].lly > boxes[1].lly {
    flip = true
    let flipped : Array[@geom.Rect] = []
    for box in boxes {
      flipped.push({ llx: box.llx, lly: -box.ury, urx: box.urx, ury: -box.lly })
    }
    boxes_copy = flipped
  }
  let polypoints : Array[@geom.Point] = []
  let boxn = boxes_copy.length()
  for bi in 0..<boxn {
    let box = boxes_copy[bi]
    let mut prev = 0
    let mut next = 0
    if bi > 0 {
      prev = if boxes_copy[bi].lly > boxes_copy[bi - 1].lly { -1 } else { 1 }
    }
    if bi + 1 < boxn {
      next = if boxes_copy[bi + 1].lly > boxes_copy[bi].lly { 1 } else { -1 }
    }
    if prev != next {
      if next == -1 || prev == 1 {
        polypoints.push({ x: box.llx, y: box.ury })
        polypoints.push({ x: box.llx, y: box.lly })
      } else {
        polypoints.push({ x: box.urx, y: box.lly })
        polypoints.push({ x: box.urx, y: box.ury })
      }
    } else if prev == 0 {
      polypoints.push({ x: box.llx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.lly })
    } else if !(prev == -1 && next == -1) {
      return []
    }
  }
  let mut bi = boxn
  while bi > 0 {
    bi = bi - 1
    let box = boxes_copy[bi]
    let mut prev = 0
    let mut next = 0
    if bi + 1 < boxn {
      prev = if boxes_copy[bi].lly > boxes_copy[bi + 1].lly { -1 } else { 1 }
    }
    if bi > 0 {
      next = if boxes_copy[bi - 1].lly > boxes_copy[bi].lly { 1 } else { -1 }
    }
    if prev != next {
      if next == -1 || prev == 1 {
        polypoints.push({ x: box.llx, y: box.ury })
        polypoints.push({ x: box.llx, y: box.lly })
      } else {
        polypoints.push({ x: box.urx, y: box.lly })
        polypoints.push({ x: box.urx, y: box.ury })
      }
    } else if prev == 0 {
      polypoints.push({ x: box.urx, y: box.lly })
      polypoints.push({ x: box.urx, y: box.ury })
    } else {
      if !(prev == -1 && next == -1) {
        return []
      }
      // Graphviz parity: add full box loop when prev==next==-1 in reverse pass.
      polypoints.push({ x: box.urx, y: box.lly })
      polypoints.push({ x: box.urx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.lly })
    }
  }
  if !flip {
    return polypoints
  }
  let restored : Array[@geom.Point] = []
  for point in polypoints {
    restored.push({ x: point.x, y: -point.y })
  }
  restored
}

///|
fn dedupe_polyline_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() <= 1 {
    return points
  }
  let out : Array[@geom.Point] = []
  out.push(points[0])
  let mut idx = 1
  while idx < points.length() {
    let p = points[idx]
    let last = out[out.length() - 1]
    if p.x != last.x || p.y != last.y {
      out.push(p)
    }
    idx = idx + 1
  }
  out
}

///|
fn route_pathplan_from_boxes(
  boxes : Array[@geom.Rect],
  start : @geom.Point,
  end : @geom.Point,
) -> PathplanRouteResult? {
  let (sanitized_boxes, start, end) = match
    sanitize_path_boxes(boxes, start, end) {
    Some(value) => value
    None => return None
  }
  if sanitized_boxes.length() < 2 {
    return None
  }
  let polygon = boxes_to_polygon_points(sanitized_boxes)
  if polygon.length() < 3 {
    return None
  }
  let path = @pathplan.shortest_path_in_poly(polygon, start, end)
  if path.length() < 2 {
    return None
  }
  Some({ points: dedupe_polyline_points(path), polygon, boxes: sanitized_boxes })
}

///|
fn polygon_edges(
  polygon : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let edges : Array[(@geom.Point, @geom.Point)] = []
  if polygon.length() < 2 {
    return edges
  }
  for i in 0..<polygon.length() {
    let next = if i + 1 < polygon.length() { i + 1 } else { 0 }
    edges.push((polygon[i], polygon[next]))
  }
  edges
}

///|
fn adjust_regular_path(
  boxes : Array[@geom.Rect],
  fb : Int,
  lb : Int,
) -> Array[@geom.Rect] {
  if boxes.length() == 0 {
    return boxes
  }
  let adjusted = boxes.copy()
  let max_idx = adjusted.length() - 1
  let mut start = fb - 1
  if start < 0 {
    start = 0
  }
  let mut end = lb
  if end > max_idx {
    end = max_idx
  }
  if start <= end {
    let mut i = start
    while i <= end {
      let mut box = adjusted[i]
      if (i - fb) % 2 == 0 {
        if box.llx >= box.urx {
          let mid = (box.llx + box.urx) / 2.0
          box = {
            llx: mid - ROUTE_MIN_WIDTH / 2.0,
            lly: box.lly,
            urx: mid + ROUTE_MIN_WIDTH / 2.0,
            ury: box.ury,
          }
        }
      } else if box.llx + ROUTE_MIN_WIDTH > box.urx {
        let mid = (box.llx + box.urx) / 2.0
        box = {
          llx: mid - ROUTE_MIN_WIDTH / 2.0,
          lly: box.lly,
          urx: mid + ROUTE_MIN_WIDTH / 2.0,
          ury: box.ury,
        }
      }
      adjusted[i] = box
      i = i + 1
    }
  }
  let mut i = 0
  while i + 1 < adjusted.length() {
    if i >= fb && i <= lb && (i - fb) % 2 == 0 {
      let mut right = adjusted[i + 1]
      let left = adjusted[i]
      if left.llx + ROUTE_MIN_WIDTH > right.urx {
        right = {
          llx: right.llx,
          lly: right.lly,
          urx: left.llx + ROUTE_MIN_WIDTH,
          ury: right.ury,
        }
      }
      if left.urx - ROUTE_MIN_WIDTH < right.llx {
        right = {
          llx: left.urx - ROUTE_MIN_WIDTH,
          lly: right.lly,
          urx: right.urx,
          ury: right.ury,
        }
      }
      adjusted[i + 1] = right
    } else if i + 1 >= fb && i < lb && (i + 1 - fb) % 2 == 0 {
      let mut left = adjusted[i]
      let right = adjusted[i + 1]
      if left.llx + ROUTE_MIN_WIDTH > right.urx {
        left = {
          llx: right.urx - ROUTE_MIN_WIDTH,
          lly: left.lly,
          urx: left.urx,
          ury: left.ury,
        }
      }
      if left.urx - ROUTE_MIN_WIDTH < right.llx {
        left = {
          llx: left.llx,
          lly: left.lly,
          urx: right.llx + ROUTE_MIN_WIDTH,
          ury: left.ury,
        }
      }
      adjusted[i] = left
    }
    i = i + 1
  }
  adjusted
}

///|
fn polyline_to_spline_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() < 2 {
    return []
  }
  let out : Array[@geom.Point] = []
  out.push(points[0])
  out.push(points[0])
  let mut i = 1
  while i + 1 < points.length() {
    let p = points[i]
    out.push(p)
    out.push(p)
    out.push(p)
    i = i + 1
  }
  let last = points[points.length() - 1]
  out.push(last)
  out.push(last)
  out
}

///|
/// Graphviz parity: limitBoxes sampling aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
fn limit_boxes_sample(
  boxes : Array[@geom.Rect],
  spline_points : Array[@geom.Point],
  delta : Double,
  fudge : Double,
) -> Unit {
  if boxes.length() == 0 || spline_points.length() < 4 {
    return ()
  }
  let num_div = delta * boxes.length().to_double()
  if num_div <= 0.0 {
    return ()
  }
  let mut spline_idx = 0
  while spline_idx + 3 < spline_points.length() {
    let p0 = spline_points[spline_idx]
    let p1 = spline_points[spline_idx + 1]
    let p2 = spline_points[spline_idx + 2]
    let p3 = spline_points[spline_idx + 3]
    let mut si = 0.0
    while si <= num_div {
      let t = si / num_div
      let mut x0 = p0.x
      let mut y0 = p0.y
      let mut x1 = p1.x
      let mut y1 = p1.y
      let mut x2 = p2.x
      let mut y2 = p2.y
      let x3 = p3.x
      let y3 = p3.y
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      x1 = x1 + t * (x2 - x1)
      y1 = y1 + t * (y2 - y1)
      x2 = x2 + t * (x3 - x2)
      y2 = y2 + t * (y3 - y2)
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      x1 = x1 + t * (x2 - x1)
      y1 = y1 + t * (y2 - y1)
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      let mut bi = 0
      while bi < boxes.length() {
        let box = boxes[bi]
        if y0 <= box.ury + fudge && y0 >= box.lly - fudge {
          let llx = if x0 < box.llx { x0 } else { box.llx }
          let urx = if x0 > box.urx { x0 } else { box.urx }
          boxes[bi] = { llx, lly: box.lly, urx, ury: box.ury }
        }
        bi = bi + 1
      }
      si = si + 1.0
    }
    spline_idx = spline_idx + 3
  }
}

///|
/// Graphviz parity: box limiting loop aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
pub fn limit_boxes_for_spline(
  boxes : Array[@geom.Rect],
  spline_points : Array[@geom.Point],
  fallback_polyline? : Array[@geom.Point] = [],
) -> Array[@geom.Rect] {
  if boxes.length() == 0 {
    return boxes
  }
  let limited = boxes.copy()
  let initial_llx = 1.0e308
  let initial_urx = -1.0e308
  let mut i = 0
  while i < limited.length() {
    let box = limited[i]
    limited[i] = {
      llx: initial_llx,
      lly: box.lly,
      urx: initial_urx,
      ury: box.ury,
    }
    i = i + 1
  }
  if spline_points.length() == 0 {
    return limited
  }
  let mut is_horizontal = true
  let mut is_vertical = true
  let base = spline_points[0]
  let fudge = 0.0001
  for point in spline_points {
    if Double::abs(base.y - point.y) > fudge {
      is_horizontal = false
    }
    if Double::abs(base.x - point.x) > fudge {
      is_vertical = false
    }
    if !is_horizontal && !is_vertical {
      break
    }
  }
  if is_horizontal || is_vertical {
    let x = base.x
    let mut idx = 0
    while idx < limited.length() {
      let box = limited[idx]
      limited[idx] = { llx: x, lly: box.lly, urx: x, ury: box.ury }
      idx = idx + 1
    }
    return limited
  }
  let mut delta = 10.0
  let mut unbounded = true
  let mut loopcnt = 0
  while unbounded && loopcnt < 15 {
    limit_boxes_sample(limited, spline_points, delta, fudge)
    unbounded = false
    for box in limited {
      if box.llx == initial_llx || box.urx == initial_urx {
        unbounded = true
        break
      }
    }
    if unbounded {
      delta = delta * 2.0
    }
    loopcnt = loopcnt + 1
  }
  if unbounded && fallback_polyline.length() >= 2 {
    let fallback_points = polyline_to_spline_points(fallback_polyline)
    limit_boxes_sample(limited, fallback_points, 10.0, fudge)
  }
  limited
}

///|
/// Graphviz parity: pathplan segment routing aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
