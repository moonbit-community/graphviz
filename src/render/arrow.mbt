///|
const ARROW_LENGTH : Double = 10.0

///|
const ARROW_WIDTH : Double = 6.0

///|
enum ArrowBase {
  Normal
  Box
  Crow
  Diamond
  Dot
  Inv
  Tee
  Vee
  Curve
  ICurve
  None
} derive(Show, Eq)

///|
struct ArrowShape {
  base : ArrowBase
  open : Bool
  left : Bool
  right : Bool
} derive(Show, Eq)

///|
fn point(x : Double, y : Double) -> @geom.Point {
  @geom.Point::{ x, y }
}

///|
fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x + b.x, a.y + b.y)
}

///|
fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x - b.x, a.y - b.y)
}

///|
fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  point(a.x * s, a.y * s)
}

///|
fn unit_vectors(
  tip : @geom.Point,
  from : @geom.Point,
) -> (@geom.Point, @geom.Point, Double) {
  let dx = tip.x - from.x
  let dy = tip.y - from.y
  let len = Double::sqrt(dx * dx + dy * dy)
  if len < 0.0001 {
    return (point(0.0, 0.0), point(0.0, 0.0), 0.0)
  }
  let dir = point(dx / len, dy / len)
  let perp = point(-dir.y, dir.x)
  (dir, perp, len)
}

///|
fn shape_table() -> Array[(String, ArrowBase)] {
  [
    ("icurve", ArrowBase::ICurve),
    ("curve", ArrowBase::Curve),
    ("diamond", ArrowBase::Diamond),
    ("normal", ArrowBase::Normal),
    ("crow", ArrowBase::Crow),
    ("box", ArrowBase::Box),
    ("tee", ArrowBase::Tee),
    ("vee", ArrowBase::Vee),
    ("pen", ArrowBase::Vee),
    ("dot", ArrowBase::Dot),
    ("inv", ArrowBase::Inv),
    ("none", ArrowBase::None),
  ]
}

///|
fn has_prefix_at(text : String, start : Int, prefix : String) -> Bool {
  let end = start + prefix.length()
  if end > text.length() {
    return false
  }
  text.unsafe_substring(start~, end~) == prefix
}

///|
fn parse_arrow_shapes(text : String?) -> Array[ArrowShape] {
  let value = match text {
    Some(v) => v.to_lower()
    None => "normal"
  }
  if value == "" {
    return [
      ArrowShape::{
        base: ArrowBase::Normal,
        open: false,
        left: false,
        right: false,
      },
    ]
  }
  if value == "none" {
    return []
  }
  let shapes : Array[ArrowShape] = []
  let names = shape_table()
  let mut index = 0
  while index < value.length() {
    if has_prefix_at(value, index, "invempty") {
      shapes.push(ArrowShape::{
        base: ArrowBase::Inv,
        open: true,
        left: false,
        right: false,
      })
      index = index + "invempty".length()
      continue
    }
    if has_prefix_at(value, index, "empty") {
      shapes.push(ArrowShape::{
        base: ArrowBase::Normal,
        open: true,
        left: false,
        right: false,
      })
      index = index + "empty".length()
      continue
    }
    let mut open = false
    let mut left = false
    let mut right = false
    let mut scanning = true
    while scanning && index < value.length() {
      if has_prefix_at(value, index, "half") {
        left = true
        index = index + "half".length()
        continue
      }
      let ch = value.unsafe_substring(start=index, end=index + 1)
      match ch {
        "o" | "e" => {
          open = true
          index = index + 1
        }
        "l" => {
          left = true
          index = index + 1
        }
        "r" => {
          right = true
          index = index + 1
        }
        _ => scanning = false
      }
    }
    let mut matched = false
    for pair in names {
      let (name, base) = pair
      if has_prefix_at(value, index, name) {
        shapes.push(ArrowShape::{ base, open, left, right })
        index = index + name.length()
        matched = true
        break
      }
    }
    if !matched {
      break
    }
  }
  if shapes.length() == 0 {
    shapes.push(ArrowShape::{
      base: ArrowBase::Normal,
      open: false,
      left: false,
      right: false,
    })
  }
  if shapes.length() > 4 {
    let trimmed : Array[ArrowShape] = []
    for i in 0..<4 {
      trimmed.push(shapes[i])
    }
    return trimmed
  }
  if shapes.length() == 4 && shapes[3].base == ArrowBase::None {
    let trimmed : Array[ArrowShape] = []
    for i in 0..<3 {
      trimmed.push(shapes[i])
    }
    return trimmed
  }
  shapes
}

///|
fn triangle_points(
  tip : @geom.Point,
  base : @geom.Point,
  perp : @geom.Point,
  half_width : Double,
  left : Bool,
  right : Bool,
) -> Array[@geom.Point] {
  let left_point = point_add(base, point_scale(perp, half_width))
  let right_point = point_add(base, point_scale(perp, -half_width))
  if left && !right {
    [tip, left_point, base]
  } else if right && !left {
    [tip, base, right_point]
  } else {
    [tip, left_point, right_point]
  }
}

///|
fn diamond_points(
  tip : @geom.Point,
  base : @geom.Point,
  perp : @geom.Point,
  half_width : Double,
  left : Bool,
  right : Bool,
) -> Array[@geom.Point] {
  let mid = point_add(tip, point_scale(point_sub(base, tip), 0.5))
  let left_point = point_add(mid, point_scale(perp, half_width))
  let right_point = point_add(mid, point_scale(perp, -half_width))
  if left && !right {
    [tip, left_point, base]
  } else if right && !left {
    [tip, base, right_point]
  } else {
    [tip, left_point, base, right_point]
  }
}

///|
fn box_points(
  front : @geom.Point,
  back : @geom.Point,
  perp : @geom.Point,
  half_width : Double,
  left : Bool,
  right : Bool,
) -> Array[@geom.Point] {
  let front_left = point_add(front, point_scale(perp, half_width))
  let front_right = point_add(front, point_scale(perp, -half_width))
  let back_left = point_add(back, point_scale(perp, half_width))
  let back_right = point_add(back, point_scale(perp, -half_width))
  if left && !right {
    [front_left, front, back, back_left]
  } else if right && !left {
    [front, front_right, back_right, back]
  } else {
    [front_left, front_right, back_right, back_left]
  }
}

///|
fn arrow_shape_primitives(
  shape : ArrowShape,
  tip : @geom.Point,
  dir : @geom.Point,
  perp : @geom.Point,
  length : Double,
  width : Double,
) -> Array[DrawOp] {
  let ops : Array[DrawOp] = []
  let filled = !shape.open
  let half_width = width / 2.0
  match shape.base {
    ArrowBase::Normal => {
      let base = point_add(tip, point_scale(dir, -length))
      let points = triangle_points(
        tip,
        base,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Vee => {
      let base = point_add(tip, point_scale(dir, -length))
      let points = triangle_points(
        tip,
        base,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Inv => {
      let base = tip
      let point_tip = point_add(tip, point_scale(dir, -length))
      let points = triangle_points(
        point_tip,
        base,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Box => {
      let back = point_add(tip, point_scale(dir, -length))
      let points = box_points(
        tip,
        back,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
      let line_end = point_add(back, point_scale(dir, -length * 0.3))
      ops.push(DrawOp::Polyline(points=[back, line_end]))
    }
    ArrowBase::Tee => {
      let tee_length = length * 0.3
      let back = point_add(tip, point_scale(dir, -tee_length))
      let points = box_points(
        tip,
        back,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
      let line_end = point_add(back, point_scale(dir, -length * 0.6))
      ops.push(DrawOp::Polyline(points=[back, line_end]))
    }
    ArrowBase::Diamond => {
      let base = point_add(tip, point_scale(dir, -length))
      let points = diamond_points(
        tip,
        base,
        perp,
        half_width,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Dot => {
      let radius = half_width
      let center = point_add(tip, point_scale(dir, -radius))
      let rect = @geom.Rect::{
        llx: center.x - radius,
        lly: center.y - radius,
        urx: center.x + radius,
        ury: center.y + radius,
      }
      ops.push(DrawOp::Ellipse(filled~, rect~))
    }
    ArrowBase::Crow => {
      let base = point_add(tip, point_scale(dir, -length))
      let wing = width * 0.75
      let left_point = point_add(tip, point_scale(perp, wing))
      let right_point = point_add(tip, point_scale(perp, -wing))
      let tail = point_add(base, point_scale(dir, length * 0.2))
      let points = [left_point, tip, right_point, tail]
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Curve | ArrowBase::ICurve => {
      let base = point_add(tip, point_scale(dir, -length))
      ops.push(DrawOp::Polyline(points=[tip, base]))
      let mut sign = 1.0
      match shape.base {
        ArrowBase::ICurve => sign = -1.0
        _ => ()
      }
      if shape.left && !shape.right {
        sign = 1.0
      } else if shape.right && !shape.left {
        sign = -1.0
      }
      let offset = point_scale(perp, width * 0.6 * sign)
      let c1 = point_add(tip, offset)
      let c2 = point_add(base, offset)
      ops.push(DrawOp::Bezier(filled=false, points=[tip, c1, c2, base]))
    }
    ArrowBase::None => {
      let base = point_add(tip, point_scale(dir, -length * 0.4))
      ops.push(DrawOp::Polyline(points=[tip, base]))
    }
  }
  ops
}

///|
pub fn arrow_primitives(
  tip : @geom.Point,
  from : @geom.Point,
  size : Double,
  penwidth : Double,
  arrowhead : String?,
) -> Array[DrawOp] {
  let (dir, perp, len) = unit_vectors(tip, from)
  let _ = penwidth
  if len < 0.0001 || size <= 0.0 {
    return []
  }
  let length = ARROW_LENGTH * size
  let width = ARROW_WIDTH * size
  let shapes = parse_arrow_shapes(arrowhead)
  if shapes.length() == 0 {
    return []
  }
  let ops : Array[DrawOp] = []
  let mut offset = 0.0
  for shape in shapes {
    let shape_tip = point_add(tip, point_scale(dir, -offset))
    let primitives = arrow_shape_primitives(
      shape, shape_tip, dir, perp, length, width,
    )
    for op in primitives {
      ops.push(op)
    }
    offset = offset + length
  }
  ops
}
