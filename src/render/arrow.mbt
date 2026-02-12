///|
const ARROW_LENGTH : Double = 10.0

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
      // Graphviz parity: keep already-parsed heads, ignore unknown suffix.
      if flags.length() == 0 {
        return []
      }
      break
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
  // Graphviz parity: ordering matches normal arrow polygon emission patterns.
  if left && !right {
    [base, left_point, tip]
  } else if right && !left {
    [tip, right_point, base]
  } else {
    [left_point, tip, right_point]
  }
}

///|
priv struct JoinTriangle {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
}

///|
fn miter_shape(
  base_left : @geom.Point,
  p : @geom.Point,
  base_right : @geom.Point,
  penwidth : Double,
) -> JoinTriangle {
  if (base_left.x == p.x && base_left.y == p.y) ||
    (base_right.x == p.x && base_right.y == p.y) {
    return JoinTriangle::{ p0: p, p1: p, p2: p }
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
    JoinTriangle::{ p0: p_bevel, p1, p2 }
  } else {
    let l = penwidth / 2.0 / @math.tan(theta / 2.0)
    let p3 = point(p1.x + l * cos_alpha, p1.y + l * sin_alpha)
    JoinTriangle::{ p0: p3, p1, p2 }
  }
}

///|
fn diamond_points(
  tip : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  left : Bool,
  right : Bool,
) -> Array[@geom.Point] {
  let v = point(-u.y / 3.0, u.x / 3.0)
  let mut p = tip
  let mut r = point_add(p, point_scale(u, 0.5))
  let mut q = point_add(p, u)

  let origin = point(0.0, 0.0)
  let unmod_left = point_sub(point_scale(u, -0.5), v)
  let unmod_right = point_add(point_scale(u, -0.5), v)
  let base_left = if right { origin } else { unmod_left }
  let base_right = if left { origin } else { unmod_right }
  let p_tip = point_scale(u, -1.0)
  let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
  let delta = point_sub(line_join_shape.p0, p_tip)

  // Graphviz parity: diamond offset uses miter join instead of fixed penwidth shift.
  p = point_sub(p, delta)
  r = point_sub(r, delta)
  q = point_sub(q, delta)

  let a0 = q
  let a1 = point_add(r, v)
  let a2 = p
  let a3 = point_sub(r, v)
  let a4 = q

  // Graphviz parity: left/right branches map to arrow_type_diamond (a2,a3,a4)/(a0,a1,a2).
  if left && !right {
    [a2, a3, a4]
  } else if right && !left {
    [a0, a1, a2]
  } else {
    [a0, a1, a2, a3]
  }
}

///|
/// Graphviz parity: normal/inv head corners use arrows.c miter projection.
fn normal_arrow_points(
  tip : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  left : Bool,
  right : Bool,
  inv : Bool,
) -> Array[@geom.Point] {
  let mut arrowwidth = 0.35
  if penwidth > 4.0 {
    arrowwidth = arrowwidth * penwidth / 4.0
  }
  let v = point(-u.y * arrowwidth, u.x * arrowwidth)
  let mut p = tip
  let mut q = point_add(p, u)

  let mut delta_base = point(0.0, 0.0)

  let origin = point(0.0, 0.0)
  let v_inv = point(-v.x, -v.y)
  let normal_left = if right { origin } else { v_inv }
  let normal_right = if left { origin } else { v }
  let base_left = if inv { normal_right } else { normal_left }
  let base_right = if inv { normal_left } else { normal_right }
  let normal_tip = point(-u.x, -u.y)
  let inv_tip = u
  let p_tip = if inv { inv_tip } else { normal_tip }

  let mut delta_tip = point(0.0, 0.0)

  if u.x != 0.0 || u.y != 0.0 {
    let cos_phi = p_tip.x / @math.hypot(p_tip.x, p_tip.y)
    let sin_phi = p_tip.y / @math.hypot(p_tip.x, p_tip.y)
    let phi = if p_tip.y > 0.0 {
      @math.acos(cos_phi)
    } else {
      -@math.acos(cos_phi)
    }

    if left {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p1 = line_join_shape.p1
      let dx = p1.x - p_tip.x
      let dy = p1.y - p_tip.y
      let hypot_p = @math.hypot(dx, dy)
      let cos_alpha = dx / hypot_p
      let alpha = if dy > 0.0 {
        @math.acos(cos_alpha)
      } else {
        -@math.acos(cos_alpha)
      }
      let gamma = alpha - phi
      let delta_tip_length = hypot_p * @math.cos(gamma)
      delta_tip = point(delta_tip_length * cos_phi, delta_tip_length * sin_phi)
    } else if right {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p2 = line_join_shape.p2
      let dx = p2.x - p_tip.x
      let dy = p2.y - p_tip.y
      let hypot_p = @math.hypot(dx, dy)
      let cos_alpha = dx / hypot_p
      let alpha = if dy > 0.0 {
        @math.acos(cos_alpha)
      } else {
        -@math.acos(cos_alpha)
      }
      let gamma = alpha - phi
      let delta_tip_length = hypot_p * @math.cos(gamma)
      delta_tip = point(delta_tip_length * cos_phi, delta_tip_length * sin_phi)
    } else {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p3 = line_join_shape.p0
      delta_tip = point_sub(p3, p_tip)
    }
    delta_base = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
  }

  let a : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
  ]

  if inv {
    p = point_add(p, delta_base)
    q = point_add(q, delta_base)
    a[0] = p
    a[4] = p
    a[1] = point_sub(p, v)
    a[2] = q
    a[3] = point_add(p, v)
  } else {
    p = point_sub(p, delta_tip)
    q = point_sub(q, delta_tip)
    a[0] = q
    a[4] = q
    a[1] = point_sub(q, v)
    a[2] = p
    a[3] = point_add(q, v)
  }

  if left {
    [a[0], a[1], a[2]]
  } else if right {
    [a[2], a[3], a[4]]
  } else {
    [a[1], a[2], a[3]]
  }
}

///|

///|
/// Graphviz parity: ARR_MOD_LEFT/ARR_MOD_RIGHT on curve heads split cubic at t=0.5.
fn bezier_split_half(
  points : Array[@geom.Point],
  keep_left : Bool,
) -> Array[@geom.Point] {
  let p0 = points[0]
  let p1 = points[1]
  let p2 = points[2]
  let p3 = points[3]
  let p01 = point((p0.x + p1.x) / 2.0, (p0.y + p1.y) / 2.0)
  let p12 = point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
  let p23 = point((p2.x + p3.x) / 2.0, (p2.y + p3.y) / 2.0)
  let p012 = point((p01.x + p12.x) / 2.0, (p01.y + p12.y) / 2.0)
  let p123 = point((p12.x + p23.x) / 2.0, (p12.y + p23.y) / 2.0)
  let p0123 = point((p012.x + p123.x) / 2.0, (p012.y + p123.y) / 2.0)
  if keep_left {
    [p0, p01, p012, p0123]
  } else {
    [p0123, p123, p23, p3]
  }
}

///|
fn arrow_shape_primitives(
  shape : ArrowShape,
  tip : @geom.Point,
  dir : @geom.Point,
  perp : @geom.Point,
  length : Double,
  penwidth : Double,
) -> Array[DrawOp] {
  let ops : Array[DrawOp] = []
  let filled = !shape.open
  match shape.base {
    ArrowBase::Normal => {
      let normal_tip = point_sub(tip, point_scale(dir, penwidth / 2.0))
      let u = point_scale(dir, -length)
      // Graphviz parity: normal half-head + miter logic follows arrow_type_normal0.
      let points = normal_arrow_points(
        normal_tip,
        u,
        penwidth,
        shape.left,
        shape.right,
        false,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Vee => {
      // Graphviz parity: vee heads back off by half penwidth to reduce overlap.
      let vee_tip = point_sub(tip, point_scale(dir, penwidth / 2.0))
      let base = point_add(vee_tip, point_scale(dir, -length))
      // Graphviz parity: vee is inverse crow, using wider 0.45 head span.
      let mut vee_half_width = length * 0.45
      let arrowsize = length / ARROW_LENGTH
      if arrowsize > 0.0 && penwidth > 4.0 * arrowsize {
        vee_half_width = vee_half_width * penwidth / (4.0 * arrowsize)
      }
      // Graphviz parity: vee half-selection follows inverse-crow orientation.
      let points = triangle_points(
        vee_tip,
        base,
        perp,
        vee_half_width,
        shape.right,
        shape.left,
      )
      // Graphviz parity: crow/vee ignore ARR_MOD_OPEN and stay filled.
      ops.push(DrawOp::Polygon(filled=true, points~))
    }
    ArrowBase::Inv => {
      let inv_tip = point_sub(tip, point_scale(dir, penwidth / 2.0))
      let u = point_scale(dir, -length)
      // Graphviz parity: inverted normal uses arrow_type_normal0 with ARR_MOD_INV.
      let points = normal_arrow_points(
        inv_tip,
        u,
        penwidth,
        shape.left,
        shape.right,
        true,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Box => {
      // Graphviz parity: box geometry follows arrows.c arrow_type_box.
      let mut p = tip
      let u = point_scale(dir, -length)
      let mut m = point_add(p, point_scale(u, 0.8))
      let mut q = point_add(p, u)
      let v = point(-u.y * 0.4, u.x * 0.4)
      if u.x != 0.0 || u.y != 0.0 {
        let p_dir = point(-u.x, -u.y)
        let p_dir_len = Double::sqrt(p_dir.x * p_dir.x + p_dir.y * p_dir.y)
        let delta = point(
          penwidth / 2.0 * p_dir.x / p_dir_len,
          penwidth / 2.0 * p_dir.y / p_dir_len,
        )
        p = point_sub(p, delta)
        m = point_sub(m, delta)
        q = point_sub(q, delta)
      }
      let points : Array[@geom.Point] = [
        point_add(p, v),
        point_sub(p, v),
        point_sub(m, v),
        point_add(m, v),
      ]
      if shape.left && !shape.right {
        points[0] = p
        points[3] = m
      } else if shape.right && !shape.left {
        points[1] = p
        points[2] = m
      }
      ops.push(DrawOp::Polygon(filled~, points~))
      ops.push(DrawOp::Polyline(points=[m, q]))
    }
    ArrowBase::Tee => {
      // Graphviz parity: tee geometry follows arrows.c arrow_type_tee.
      let mut p = tip
      let u = point_scale(dir, -length)
      let mut q = point_add(p, u)
      let mut m = point_add(p, point_scale(u, 0.2))
      let mut n = point_add(p, point_scale(u, 0.6))
      let v = point(-u.y, u.x)
      let u_len = Double::sqrt(u.x * u.x + u.y * u.y)
      let polygon_extend_over_polyline = penwidth / 2.0 - 0.2 * u_len
      if u_len > 0.0 && polygon_extend_over_polyline > 0.0 {
        let p_dir = point(-u.x, -u.y)
        let p_dir_len = Double::sqrt(p_dir.x * p_dir.x + p_dir.y * p_dir.y)
        let delta = point(
          polygon_extend_over_polyline * p_dir.x / p_dir_len,
          polygon_extend_over_polyline * p_dir.y / p_dir_len,
        )
        p = point_sub(p, delta)
        m = point_sub(m, delta)
        n = point_sub(n, delta)
        q = point_sub(q, delta)
      }
      let points : Array[@geom.Point] = [
        point_add(m, v),
        point_sub(m, v),
        point_sub(n, v),
        point_add(n, v),
      ]
      if shape.left && !shape.right {
        points[0] = m
        points[3] = n
      } else if shape.right && !shape.left {
        points[1] = m
        points[2] = n
      }
      // Graphviz parity: tee heads are always filled (ARR_MOD_OPEN ignored).
      ops.push(DrawOp::Polygon(filled=true, points~))
      ops.push(DrawOp::Polyline(points=[p, q]))
    }
    ArrowBase::Diamond => {
      // Graphviz parity: diamond still starts with penwidth/2 backoff from node edge.
      let diamond_tip = point_sub(tip, point_scale(dir, penwidth / 2.0))
      let u = point_scale(dir, -length)
      let points = diamond_points(
        diamond_tip,
        u,
        penwidth,
        shape.left,
        shape.right,
      )
      ops.push(DrawOp::Polygon(filled~, points~))
    }
    ArrowBase::Dot => {
      // Graphviz parity: dot heads back off by half penwidth to avoid node overlap.
      let delta = point_scale(dir, penwidth / 2.0)
      let dot_tip = point_sub(tip, delta)
      // Graphviz parity: dot radius derives from arrow length, not base width.
      let radius = length / 2.0
      let center = point_add(dot_tip, point_scale(dir, -radius))
      let rect = @geom.Rect::{
        llx: center.x - radius,
        lly: center.y - radius,
        urx: center.x + radius,
        ury: center.y + radius,
      }
      ops.push(DrawOp::Ellipse(filled~, rect~))
    }
    ArrowBase::Crow => {
      // Graphviz parity: crow heads back off by half penwidth to avoid overlap.
      let crow_tip = point_sub(tip, point_scale(dir, penwidth / 2.0))
      let base = point_add(crow_tip, point_scale(dir, -length))
      // Graphviz parity: crow wing span is 0.45 * head length.
      let wing = length * 0.45
      let left_point = point_add(crow_tip, point_scale(perp, wing))
      let right_point = point_add(crow_tip, point_scale(perp, -wing))
      let tail = point_add(base, point_scale(dir, length * 0.2))
      let points = if shape.left && !shape.right {
        [left_point, crow_tip, tail]
      } else if shape.right && !shape.left {
        [crow_tip, right_point, tail]
      } else {
        [left_point, crow_tip, right_point, tail]
      }
      // Graphviz parity: crow heads are always filled (ARR_MOD_OPEN ignored).
      ops.push(DrawOp::Polygon(filled=true, points~))
    }
    ArrowBase::Curve | ArrowBase::ICurve => {
      // Graphviz parity: curve/icurve control points follow arrows.c arrow_type_curve.
      let mut p = tip
      let u = point_scale(dir, -length)
      let inv = shape.base == ArrowBase::ICurve
      if !inv && (u.x != 0.0 || u.y != 0.0) {
        let p_dir = point(-u.x, -u.y)
        let p_dir_len = Double::sqrt(p_dir.x * p_dir.x + p_dir.y * p_dir.y)
        let cos_phi = p_dir.x / p_dir_len
        let sin_phi = p_dir.y / p_dir_len
        let delta = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
        p = point_sub(p, delta)
      }
      let q = point_add(p, u)
      ops.push(DrawOp::Polyline(points=[p, q]))
      let mut arrowwidth = 0.5
      if penwidth > 4.0 {
        arrowwidth = 0.5 * penwidth / 4.0
      }
      let v = point(-u.y * arrowwidth, u.x * arrowwidth)
      let w = point(v.y, -v.x)
      let mut curve_points = [
        point(p.x + v.x + w.x, p.y + v.y + w.y),
        point(0.0, 0.0),
        point(0.0, 0.0),
        point(p.x - v.x + w.x, p.y - v.y + w.y),
      ]
      if inv {
        curve_points[1] = point(
          p.x + 0.95 * v.x + w.x + w.x * 4.0 / 3.0,
          curve_points[0].y + w.y * 4.0 / 3.0,
        )
        curve_points[2] = point(
          p.x - 0.95 * v.x + w.x + w.x * 4.0 / 3.0,
          curve_points[3].y + w.y * 4.0 / 3.0,
        )
      } else {
        curve_points[1] = point(
          p.x + 0.95 * v.x + w.x - w.x * 4.0 / 3.0,
          curve_points[0].y - w.y * 4.0 / 3.0,
        )
        curve_points[2] = point(
          p.x - 0.95 * v.x + w.x - w.x * 4.0 / 3.0,
          curve_points[3].y - w.y * 4.0 / 3.0,
        )
      }
      if shape.left && !shape.right {
        curve_points = bezier_split_half(curve_points, false)
      } else if shape.right && !shape.left {
        curve_points = bezier_split_half(curve_points, true)
      }
      ops.push(DrawOp::Bezier(filled=false, points=curve_points))
    }
    ArrowBase::None => {
      // Graphviz parity: internal "none" heads draw a short gap polyline.
      let base = point_add(tip, point_scale(dir, -length))
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
  if size <= 0.0 || penwidth <= 0.0 {
    return []
  }
  // Graphviz parity: stabilize arrow direction by epsilon-adjusting the edge vector.
  let mut ux = from.x - tip.x
  let mut uy = from.y - tip.y
  let raw_len = Double::sqrt(ux * ux + uy * uy)
  if raw_len < EPSILON {
    return []
  }
  let scale = ARROW_LENGTH * size / (raw_len + EPSILON)
  let ux_adjust = if ux >= 0.0 { EPSILON } else { -EPSILON }
  let uy_adjust = if uy >= 0.0 { EPSILON } else { -EPSILON }
  ux = ux + ux_adjust
  uy = uy + uy_adjust
  let adjusted_from = point(tip.x + ux * scale, tip.y + uy * scale)
  let (dir, perp, len) = unit_vectors(tip, adjusted_from)
  if len < EPSILON {
    return []
  }
  let shapes = parse_arrow_shapes(arrowhead)
  if shapes.length() == 0 {
    return []
  }
  let ops : Array[DrawOp] = []
  let mut offset = 0.0
  for shape in shapes {
    let shape_len = len * arrow_length_factor(shape.base)
    let shape_tip = point_add(tip, point_scale(dir, -offset))
    let primitives = arrow_shape_primitives(
      shape,
      shape_tip,
      dir,
      perp,
      shape_len,
      penwidth,
    )
    for op in primitives {
      ops.push(op)
    }
    offset = offset + shape_len
  }
  ops
}
