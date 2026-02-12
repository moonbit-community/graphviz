///|
const ARROW_LENGTH : Double = 10.0

///|
const ARROW_WIDTH : Double = 6.0

///|
const EPSILON : Double = 0.0001

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
  if len < EPSILON {
    return (point(0.0, 0.0), point(0.0, 0.0), 0.0)
  }
  let dir = point(dx / len, dy / len)
  let perp = point(-dir.y, dir.x)
  (dir, perp, len)
}

///|
const NUMB_OF_ARROW_HEADS : Int = 4

///|
const BITS_PER_ARROW_TYPE : Int = 4

///|
const ARR_TYPE_NONE : Int = 0

///|
const ARR_TYPE_NORM : Int = 1

///|
const ARR_TYPE_CROW : Int = 2

///|
const ARR_TYPE_TEE : Int = 3

///|
const ARR_TYPE_BOX : Int = 4

///|
const ARR_TYPE_DIAMOND : Int = 5

///|
const ARR_TYPE_DOT : Int = 6

///|
const ARR_TYPE_CURVE : Int = 7

///|
const ARR_TYPE_GAP : Int = 8

///|
const ARR_MOD_OPEN : Int = 1 << (BITS_PER_ARROW_TYPE + 0)

///|
const ARR_MOD_INV : Int = 1 << (BITS_PER_ARROW_TYPE + 1)

///|
const ARR_MOD_LEFT : Int = 1 << (BITS_PER_ARROW_TYPE + 2)

///|
const ARR_MOD_RIGHT : Int = 1 << (BITS_PER_ARROW_TYPE + 3)

///|
fn has_prefix_at(text : String, start : Int, prefix : String) -> Bool {
  let end = start + prefix.length()
  if end > text.length() {
    return false
  }
  text.unsafe_substring(start~, end~) == prefix
}

///|
fn arrow_synonyms() -> Array[(String, Int)] {
  [
    ("invempty", ARR_TYPE_NORM | ARR_MOD_INV | ARR_MOD_OPEN),
  ]
}

///|
fn arrow_mods() -> Array[(String, Int)] {
  [
    ("o", ARR_MOD_OPEN),
    ("r", ARR_MOD_RIGHT),
    ("l", ARR_MOD_LEFT),
    ("e", ARR_MOD_OPEN),
    ("half", ARR_MOD_LEFT),
  ]
}

///|
fn arrow_names() -> Array[(String, Int)] {
  [
    ("normal", ARR_TYPE_NORM),
    ("crow", ARR_TYPE_CROW),
    ("tee", ARR_TYPE_TEE),
    ("box", ARR_TYPE_BOX),
    ("diamond", ARR_TYPE_DIAMOND),
    ("dot", ARR_TYPE_DOT),
    ("none", ARR_TYPE_GAP),
    ("inv", ARR_TYPE_NORM | ARR_MOD_INV),
    ("vee", ARR_TYPE_CROW | ARR_MOD_INV),
    ("pen", ARR_TYPE_CROW | ARR_MOD_INV),
    ("mpty", ARR_TYPE_NORM),
    ("curve", ARR_TYPE_CURVE),
    ("icurve", ARR_TYPE_CURVE | ARR_MOD_INV),
  ]
}

///|
fn arrow_match_name_frag(
  value : String,
  start : Int,
  names : Array[(String, Int)],
  flag : Int,
) -> (Int, Int) {
  for pair in names {
    let (name, arrow_flag) = pair
    if has_prefix_at(value, start, name) {
      return (start + name.length(), flag | arrow_flag)
    }
  }
  (start, flag)
}

///|
fn arrow_match_shape(value : String, start : Int) -> (Int, Int) {
  let type_mask = (1 << BITS_PER_ARROW_TYPE) - 1
  let (syn_rest, syn_flag) =
    arrow_match_name_frag(value, start, arrow_synonyms(), ARR_TYPE_NONE)
  if syn_rest != start {
    return (syn_rest, syn_flag)
  }
  let mut rest = start
  let mut flag = ARR_TYPE_NONE
  while true {
    let (next, next_flag) =
      arrow_match_name_frag(value, rest, arrow_mods(), flag)
    if next == rest {
      break
    }
    rest = next
    flag = next_flag
  }
  let (name_rest, name_flag) =
    arrow_match_name_frag(value, rest, arrow_names(), flag)
  flag = name_flag
  rest = name_rest
  if flag != ARR_TYPE_NONE && (flag & type_mask) == 0 {
    flag = flag | ARR_TYPE_NORM
  }
  (rest, flag)
}

///|
fn parse_arrow_flags(value : String?) -> Array[Int] {
  let text = match value {
    Some(v) => v.to_lower()
    None => "normal"
  }
  if text == "" {
    return [ARR_TYPE_NORM]
  }
  let flags : Array[Int] = []
  let mut idx = 0
  while idx < text.length() && flags.length() < NUMB_OF_ARROW_HEADS {
    let (next, parsed) = arrow_match_shape(text, idx)
    if parsed == ARR_TYPE_NONE {
      return []
    }
    let mut flag = parsed
    if flag == ARR_TYPE_GAP && flags.length() == NUMB_OF_ARROW_HEADS - 1 {
      flag = ARR_TYPE_NONE
    }
    if flag == ARR_TYPE_GAP && flags.length() == 0 && next >= text.length() {
      flag = ARR_TYPE_NONE
    }
    if flag != ARR_TYPE_NONE {
      flags.push(flag)
    }
    idx = next
  }
  flags
}

///|
fn arrow_type_mask(flag : Int) -> Int {
  let mask = (1 << BITS_PER_ARROW_TYPE) - 1
  flag & mask
}

///|
fn arrow_flag_to_shape(flag : Int) -> ArrowShape? {
  let open = (flag & ARR_MOD_OPEN) != 0
  let left = (flag & ARR_MOD_LEFT) != 0
  let right = (flag & ARR_MOD_RIGHT) != 0
  let inv = (flag & ARR_MOD_INV) != 0
  let base = match arrow_type_mask(flag) {
    ARR_TYPE_NORM => if inv { ArrowBase::Inv } else { ArrowBase::Normal }
    ARR_TYPE_CROW => if inv { ArrowBase::Vee } else { ArrowBase::Crow }
    ARR_TYPE_TEE => ArrowBase::Tee
    ARR_TYPE_BOX => ArrowBase::Box
    ARR_TYPE_DIAMOND => ArrowBase::Diamond
    ARR_TYPE_DOT => ArrowBase::Dot
    ARR_TYPE_CURVE => if inv { ArrowBase::ICurve } else { ArrowBase::Curve }
    ARR_TYPE_GAP => ArrowBase::None
    _ => return None
  }
  Some(ArrowShape::{ base, open, left, right })
}

///|
fn parse_arrow_shapes(text : String?) -> Array[ArrowShape] {
  let flags = parse_arrow_flags(text)
  let shapes : Array[ArrowShape] = []
  for flag in flags {
    match arrow_flag_to_shape(flag) {
      Some(shape) => shapes.push(shape)
      None => ()
    }
  }
  shapes
}

///|
/// Graphviz parity: per-head length factors follow arrows.c arrow_gen_type.
fn arrow_length_factor(base : ArrowBase) -> Double {
  match base {
    ArrowBase::Normal => 1.0
    ArrowBase::Box => 1.0
    ArrowBase::Crow => 1.0
    ArrowBase::Diamond => 1.2
    ArrowBase::Dot => 0.8
    ArrowBase::Inv => 1.0
    ArrowBase::Tee => 0.5
    ArrowBase::Vee => 1.0
    ArrowBase::Curve => 1.0
    ArrowBase::ICurve => 1.0
    ArrowBase::None => 0.5
  }
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
      // Graphviz parity: dot radius derives from arrow length, not base width.
      let radius = length / 2.0
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
      // Graphviz parity: "none" consumes arrow space but draws no primitive.
      ()
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
  if len < EPSILON || size <= 0.0 || penwidth <= 0.0 {
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
    let shape_len = length * arrow_length_factor(shape.base)
    let shape_tip = point_add(tip, point_scale(dir, -offset))
    let primitives = arrow_shape_primitives(
      shape,
      shape_tip,
      dir,
      perp,
      shape_len,
      width,
    )
    for op in primitives {
      ops.push(op)
    }
    offset = offset + shape_len
  }
  ops
}
