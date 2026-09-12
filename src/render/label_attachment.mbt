///|
fn attachment_distance_squared(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy
}

///|
fn attachment_curve_point(
  points : Array[@geom.Point],
  start : Int,
  t : Double,
) -> @geom.Point {
  let work = [
    points[start],
    points[start + 1],
    points[start + 2],
    points[start + 3],
  ]
  for count = 3; count > 0; count = count - 1 {
    for i in 0..<count {
      work[i] = {
        x: (1.0 - t) * work[i].x + t * work[i + 1].x,
        y: (1.0 - t) * work[i].y + t * work[i + 1].y,
      }
    }
  }
  work[0]
}

///|
/// Graphviz emit_attachment/dotneato_closest geometry. Select the cubic by
/// its nearest control point, then use upstream's endpoint-distance search.
pub fn label_attachment(
  text : String,
  pos : @geom.Point,
  width : Double,
  height : Double,
  splines : Array[@geom.Spline],
) -> Array[@geom.Point] {
  guard text.trim(chars=" \t\n\r\u000b\u000c") != "" else { [] }
  let mut selected : (Array[@geom.Point], Int)? = None
  let mut best_distance = 1.0e38
  for spline in splines {
    guard spline.points.length() >= 4 else { continue }
    for i, point in spline.points {
      let distance = attachment_distance_squared(point, pos)
      if selected is None || distance < best_distance {
        selected = Some((spline.points, i))
        best_distance = distance
      }
    }
  }
  guard selected is Some((points, nearest)) else { [] }
  let nearest = if nearest == points.length() - 1 {
    nearest - 1
  } else {
    nearest
  }
  let start = 3 * (nearest / 3)
  guard start + 3 < points.length() else { [] }
  let closest = for low = 0.0, high = 1.0, low_distance = attachment_distance_squared(
                        points[start],
                        pos,
                      ), high_distance = attachment_distance_squared(
                        points[start + 3],
                        pos,
                      ) {
    let t = (low + high) / 2.0
    let point = attachment_curve_point(points, start, t)
    if (low_distance - high_distance).abs() < 1.0 ||
      (high - low).abs() < 0.00001 {
      break point
    }
    let distance = attachment_distance_squared(point, pos)
    if low_distance < high_distance {
      continue low, t, low_distance, distance
    } else {
      continue t, high, distance, high_distance
    }
  }
  let right = pos.x + width / 2.0
  let bottom = pos.y - height / 2.0
  [{ x: right, y: bottom, }, { x: right - width, y: bottom, }, closest]
}
