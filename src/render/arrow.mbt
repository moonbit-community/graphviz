///|
const ARROW_LENGTH : Double = 10.0

///|
const EPSILON : Double = 0.0001

///|
priv struct Triangle {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
}

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
  [("invempty", ARR_TYPE_NORM | ARR_MOD_INV | ARR_MOD_OPEN)]
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
  let (syn_rest, syn_flag) = arrow_match_name_frag(
    value,
    start,
    arrow_synonyms(),
    ARR_TYPE_NONE,
  )
  if syn_rest != start {
    return (syn_rest, syn_flag)
  }
  let mut rest = start
  let mut flag = ARR_TYPE_NONE
  while true {
    let (next, next_flag) = arrow_match_name_frag(
      value,
      rest,
      arrow_mods(),
      flag,
    )
    if next == rest {
      break
    }
    rest = next
    flag = next_flag
  }
  let (name_rest, name_flag) = arrow_match_name_frag(
    value,
    rest,
    arrow_names(),
    flag,
  )
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
fn arrow_lenfact(arrow_type : Int) -> Double {
  match arrow_type {
    ARR_TYPE_NORM => 1.0
    ARR_TYPE_CROW => 1.0
    ARR_TYPE_TEE => 0.5
    ARR_TYPE_BOX => 1.0
    ARR_TYPE_DIAMOND => 1.2
    ARR_TYPE_DOT => 0.8
    ARR_TYPE_CURVE => 1.0
    ARR_TYPE_GAP => 0.5
    _ => 1.0
  }
}

///|
/// Graphviz parity: miter/bevel join geometry mirrors arrows.c miter_shape.
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
/// Graphviz parity: keep normal/inv join math aligned with arrows.c arrow_type_normal0.
fn arrow_type_normal0(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[@geom.Point]) {
  let mut arrowwidth = 0.35
  if penwidth > 4.0 {
    arrowwidth = arrowwidth * penwidth / 4.0
  }
  let v = point(-u.y * arrowwidth, u.x * arrowwidth)
  let mut p = p_in
  let mut q = point(p.x + u.x, p.y + u.y)
  let mut delta_base = point(0.0, 0.0)
  let origin = point(0.0, 0.0)
  let v_inv = point(-v.x, -v.y)
  let normal_left = if (flag & ARR_MOD_RIGHT) != 0 { origin } else { v_inv }
  let normal_right = if (flag & ARR_MOD_LEFT) != 0 { origin } else { v }
  let base_left = if (flag & ARR_MOD_INV) != 0 {
    normal_right
  } else {
    normal_left
  }
  let base_right = if (flag & ARR_MOD_INV) != 0 {
    normal_left
  } else {
    normal_right
  }
  let normal_tip = point(-u.x, -u.y)
  let inv_tip = u
  let p_tip = if (flag & ARR_MOD_INV) != 0 { inv_tip } else { normal_tip }
  let mut delta_tip = point(0.0, 0.0)
  if u.x != 0.0 || u.y != 0.0 {
    let cos_phi = p_tip.x / @math.hypot(p_tip.x, p_tip.y)
    let sin_phi = p_tip.y / @math.hypot(p_tip.x, p_tip.y)
    let phi = if p_tip.y > 0.0 {
      @math.acos(cos_phi)
    } else {
      -@math.acos(cos_phi)
    }
    if (flag & ARR_MOD_LEFT) != 0 {
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
    } else if (flag & ARR_MOD_RIGHT) != 0 {
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
  if (flag & ARR_MOD_INV) != 0 {
    p = point_add(p, delta_base)
    q = point_add(q, delta_base)
    a[0] = p
    a[4] = p
    a[1] = point_sub(p, v)
    a[2] = q
    a[3] = point_add(p, v)
    q = point_add(q, delta_tip)
  } else {
    p = point_sub(p, delta_tip)
    q = point_sub(q, delta_tip)
    a[0] = q
    a[4] = q
    a[1] = point_sub(q, v)
    a[2] = p
    a[3] = point_add(q, v)
    q = point_sub(q, delta_base)
  }
  (q, a)
}

///|
fn arrow_type_normal(
  p : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let (q, points) = arrow_type_normal0(p, u, penwidth, flag)
  let filled = (flag & ARR_MOD_OPEN) == 0
  let polygon_points = if (flag & ARR_MOD_LEFT) != 0 {
    [points[0], points[1], points[2]]
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    [points[2], points[3], points[4]]
  } else {
    [points[1], points[2], points[3]]
  }
  (q, [DrawOp::Polygon(filled~, points=polygon_points)])
}

///|
/// Graphviz parity: keep crow/vee join math aligned with arrows.c arrow_type_crow0.
fn arrow_type_crow0(
  p_in : @geom.Point,
  u : @geom.Point,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[@geom.Point]) {
  let mut p = p_in
  let mut arrowwidth = 0.45
  if penwidth > 4.0 * arrowsize && (flag & ARR_MOD_INV) != 0 {
    arrowwidth = arrowwidth * penwidth / (4.0 * arrowsize)
  }
  let mut shaftwidth = 0.0
  if penwidth > 1.0 && (flag & ARR_MOD_INV) != 0 {
    shaftwidth = 0.05 * (penwidth - 1.0) / arrowsize
  }
  let v = point(-u.y * arrowwidth, u.x * arrowwidth)
  let w = point(-u.y * shaftwidth, u.x * shaftwidth)
  let mut q = point(p.x + u.x, p.y + u.y)
  let m = point(p.x + u.x * 0.5, p.y + u.y * 0.5)
  let mut delta_base = point(0.0, 0.0)
  let origin = point(0.0, 0.0)
  let v_inv = point(-v.x, -v.y)
  let normal_left = if (flag & ARR_MOD_RIGHT) != 0 { origin } else { v }
  let normal_right = if (flag & ARR_MOD_LEFT) != 0 { origin } else { v_inv }
  let base_left = if (flag & ARR_MOD_INV) != 0 {
    normal_right
  } else {
    normal_left
  }
  let base_right = if (flag & ARR_MOD_INV) != 0 {
    normal_left
  } else {
    normal_right
  }
  let normal_tip = u
  let inv_tip = point(-u.x, -u.y)
  let p_tip = if (flag & ARR_MOD_INV) != 0 { inv_tip } else { normal_tip }
  let mut delta_tip = point(0.0, 0.0)
  if u.x != 0.0 || u.y != 0.0 {
    let cos_phi = p_tip.x / @math.hypot(p_tip.x, p_tip.y)
    let sin_phi = p_tip.y / @math.hypot(p_tip.x, p_tip.y)
    let phi = if p_tip.y > 0.0 {
      @math.acos(cos_phi)
    } else {
      -@math.acos(cos_phi)
    }
    if ((flag & ARR_MOD_LEFT) != 0 && (flag & ARR_MOD_INV) != 0) ||
      ((flag & ARR_MOD_RIGHT) != 0 && (flag & ARR_MOD_INV) == 0) {
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
    } else if ((flag & ARR_MOD_LEFT) != 0 && (flag & ARR_MOD_INV) == 0) ||
      ((flag & ARR_MOD_RIGHT) != 0 && (flag & ARR_MOD_INV) != 0) {
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
    } else {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p3 = line_join_shape.p0
      delta_tip = point_sub(p3, p_tip)
    }
    if (flag & ARR_MOD_INV) != 0 {
      delta_base = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
    } else {
      let toe_base_left = point_add(point_sub(m, q), w)
      let toe_base_right = origin
      let toe_p = point_sub(v, u)
      let toe_line_join_shape = miter_shape(
        toe_base_left, toe_p, toe_base_right, penwidth,
      )
      let p1 = toe_line_join_shape.p1
      let dx = p1.x - toe_p.x
      let dy = p1.y - toe_p.y
      let hypot_p = @math.hypot(dx, dy)
      let cos_alpha = dx / hypot_p
      let alpha = if dy > 0.0 {
        @math.acos(cos_alpha)
      } else {
        -@math.acos(cos_alpha)
      }
      let gamma = alpha - phi
      let delta_tip_length = -hypot_p * @math.cos(gamma)
      delta_base = point(delta_tip_length * cos_phi, delta_tip_length * sin_phi)
    }
  }
  let a : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
  ]
  if (flag & ARR_MOD_INV) != 0 {
    p = point_sub(p, delta_tip)
    q = point_sub(q, delta_tip)
    a[0] = p
    a[8] = p
    a[1] = point(q.x - v.x, q.y - v.y)
    a[2] = point(m.x - w.x, m.y - w.y)
    a[3] = point(q.x - w.x, q.y - w.y)
    a[4] = q
    a[5] = point(q.x + w.x, q.y + w.y)
    a[6] = point(m.x + w.x, m.y + w.y)
    a[7] = point(q.x + v.x, q.y + v.y)
    q = point_sub(q, delta_base)
  } else {
    p = point_add(p, delta_base)
    q = point_add(q, delta_base)
    a[0] = q
    a[8] = q
    a[1] = point(p.x - v.x, p.y - v.y)
    a[2] = point(m.x - w.x, m.y - w.y)
    a[3] = point(p.x + delta_base.x, p.y + delta_base.y)
    a[4] = point_add(p, delta_base)
    a[5] = point(p.x + delta_base.x, p.y + delta_base.y)
    a[6] = point(m.x + w.x, m.y + w.y)
    a[7] = point(p.x + v.x, p.y + v.y)
    q = point_add(q, delta_tip)
  }
  (q, a)
}

///|
fn arrow_type_crow(
  p : @geom.Point,
  u : @geom.Point,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let (q, points) = arrow_type_crow0(p, u, arrowsize, penwidth, flag)
  let polygon_points = if (flag & ARR_MOD_LEFT) != 0 {
    [points[0], points[1], points[2], points[3], points[4]]
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    [points[4], points[5], points[6], points[7], points[8]]
  } else {
    [
      points[0],
      points[1],
      points[2],
      points[3],
      points[4],
      points[5],
      points[6],
      points[7],
    ]
  }
  (q, [DrawOp::Polygon(filled=true, points=polygon_points)])
}

///|
fn arrow_type_gap(
  p : @geom.Point,
  u : @geom.Point,
) -> (@geom.Point, Array[DrawOp]) {
  let q = point(p.x + u.x, p.y + u.y)
  (q, [DrawOp::Polyline(points=[p, q])])
}

///|
fn arrow_type_tee(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let mut p = p_in
  let mut m = point(p.x + u.x * 0.2, p.y + u.y * 0.2)
  let mut n = point(p.x + u.x * 0.6, p.y + u.y * 0.6)
  let mut q = point(p.x + u.x, p.y + u.y)
  let v = point(-u.y, u.x)
  let length = @math.hypot(u.x, u.y)
  let polygon_extend_over_polyline = penwidth / 2.0 - 0.2 * length
  if length > 0.0 && polygon_extend_over_polyline > 0.0 {
    let p_dir = point(-u.x, -u.y)
    let cos_phi = p_dir.x / @math.hypot(p_dir.x, p_dir.y)
    let sin_phi = p_dir.y / @math.hypot(p_dir.x, p_dir.y)
    let delta = point(
      polygon_extend_over_polyline * cos_phi,
      polygon_extend_over_polyline * sin_phi,
    )
    p = point_sub(p, delta)
    m = point_sub(m, delta)
    n = point_sub(n, delta)
    q = point_sub(q, delta)
  }
  let a : Array[@geom.Point] = [
    point(m.x + v.x, m.y + v.y),
    point(m.x - v.x, m.y - v.y),
    point(n.x - v.x, n.y - v.y),
    point(n.x + v.x, n.y + v.y),
  ]
  if (flag & ARR_MOD_LEFT) != 0 {
    a[0] = m
    a[3] = n
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    a[1] = m
    a[2] = n
  }
  let ops : Array[DrawOp] = []
  ops.push(DrawOp::Polygon(filled=true, points=a))
  ops.push(DrawOp::Polyline(points=[p, q]))
  (q, ops)
}

///|
fn arrow_type_box(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let mut p = p_in
  let mut m = point(p.x + u.x * 0.8, p.y + u.y * 0.8)
  let mut q = point(p.x + u.x, p.y + u.y)
  let v = point(-u.y * 0.4, u.x * 0.4)
  let mut delta = point(0.0, 0.0)
  if u.x != 0.0 || u.y != 0.0 {
    let p_dir = point(-u.x, -u.y)
    let cos_phi = p_dir.x / @math.hypot(p_dir.x, p_dir.y)
    let sin_phi = p_dir.y / @math.hypot(p_dir.x, p_dir.y)
    delta = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
  }
  p = point_sub(p, delta)
  m = point_sub(m, delta)
  q = point_sub(q, delta)
  let a : Array[@geom.Point] = [
    point(p.x + v.x, p.y + v.y),
    point(p.x - v.x, p.y - v.y),
    point(m.x - v.x, m.y - v.y),
    point(m.x + v.x, m.y + v.y),
  ]
  if (flag & ARR_MOD_LEFT) != 0 {
    a[0] = p
    a[3] = m
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    a[1] = p
    a[2] = m
  }
  let ops : Array[DrawOp] = []
  let filled = (flag & ARR_MOD_OPEN) == 0
  ops.push(DrawOp::Polygon(filled~, points=a))
  ops.push(DrawOp::Polyline(points=[m, q]))
  (q, ops)
}

///|
/// Graphviz parity: keep diamond join math aligned with arrows.c arrow_type_diamond0.
fn arrow_type_diamond0(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[@geom.Point]) {
  let v = point(-u.y / 3.0, u.x / 3.0)
  let mut p = p_in
  let mut r = point(p.x + u.x / 2.0, p.y + u.y / 2.0)
  let mut q = point(p.x + u.x, p.y + u.y)
  let origin = point(0.0, 0.0)
  let unmod_left = point_sub(point_scale(u, -0.5), v)
  let unmod_right = point_add(point_scale(u, -0.5), v)
  let base_left = if (flag & ARR_MOD_RIGHT) != 0 { origin } else { unmod_left }
  let base_right = if (flag & ARR_MOD_LEFT) != 0 { origin } else { unmod_right }
  let tip = point_scale(u, -1.0)
  let p_tip = tip
  let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
  let p3 = line_join_shape.p0
  let delta = point_sub(p3, p_tip)
  p = point_sub(p, delta)
  r = point_sub(r, delta)
  q = point_sub(q, delta)
  let a : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
  ]
  a[0] = q
  a[4] = q
  a[1] = point_add(r, v)
  a[2] = p
  a[3] = point_sub(r, v)
  q = point_sub(q, delta)
  (q, a)
}

///|
fn arrow_type_diamond(
  p : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let (q, points) = arrow_type_diamond0(p, u, penwidth, flag)
  let filled = (flag & ARR_MOD_OPEN) == 0
  let polygon_points = if (flag & ARR_MOD_LEFT) != 0 {
    [points[2], points[3], points[4]]
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    [points[0], points[1], points[2]]
  } else {
    [points[0], points[1], points[2], points[3]]
  }
  (q, [DrawOp::Polygon(filled~, points=polygon_points)])
}

///|
fn arrow_type_dot(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let mut p = p_in
  let mut delta = point(0.0, 0.0)
  if u.x != 0.0 || u.y != 0.0 {
    let p_dir = point(-u.x, -u.y)
    let cos_phi = p_dir.x / @math.hypot(p_dir.x, p_dir.y)
    let sin_phi = p_dir.y / @math.hypot(p_dir.x, p_dir.y)
    delta = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
    p = point_sub(p, delta)
  }
  let r = @math.hypot(u.x, u.y) / 2.0
  let center = point(p.x + u.x / 2.0, p.y + u.y / 2.0)
  let rect = @geom.Rect::{
    llx: center.x - r,
    lly: center.y - r,
    urx: center.x + r,
    ury: center.y + r,
  }
  let filled = (flag & ARR_MOD_OPEN) == 0
  let mut q = point(p.x + u.x, p.y + u.y)
  q = point_sub(q, delta)
  (q, [DrawOp::Ellipse(filled~, rect~)])
}

///|
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
/// Graphviz parity: curve/icurve cubic control points follow arrows.c arrow_type_curve.
fn arrow_type_curve(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let line_start = p_in
  let mut p = p_in
  let mut arrowwidth = 0.5
  if penwidth > 4.0 {
    arrowwidth = 0.5 * penwidth / 4.0
  }
  if (flag & ARR_MOD_INV) == 0 && (u.x != 0.0 || u.y != 0.0) {
    let p_dir = point(-u.x, -u.y)
    let cos_phi = p_dir.x / @math.hypot(p_dir.x, p_dir.y)
    let sin_phi = p_dir.y / @math.hypot(p_dir.x, p_dir.y)
    let delta = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
    p = point_sub(p, delta)
  }
  let q = point(p.x + u.x, p.y + u.y)
  let v = point(-u.y * arrowwidth, u.x * arrowwidth)
  let w = point(v.y, -v.x)
  let mut af : Array[@geom.Point] = [
    point(p.x + v.x + w.x, p.y + v.y + w.y),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(p.x - v.x + w.x, p.y - v.y + w.y),
  ]
  if (flag & ARR_MOD_INV) != 0 {
    af[1] = point(
      p.x + 0.95 * v.x + w.x + w.x * 4.0 / 3.0,
      af[0].y + w.y * 4.0 / 3.0,
    )
    af[2] = point(
      p.x - 0.95 * v.x + w.x + w.x * 4.0 / 3.0,
      af[3].y + w.y * 4.0 / 3.0,
    )
  } else {
    af[1] = point(
      p.x + 0.95 * v.x + w.x - w.x * 4.0 / 3.0,
      af[0].y - w.y * 4.0 / 3.0,
    )
    af[2] = point(
      p.x - 0.95 * v.x + w.x - w.x * 4.0 / 3.0,
      af[3].y - w.y * 4.0 / 3.0,
    )
  }
  if (flag & ARR_MOD_LEFT) != 0 {
    af = bezier_split_half(af, false)
  } else if (flag & ARR_MOD_RIGHT) != 0 {
    af = bezier_split_half(af, true)
  }
  let ops : Array[DrawOp] = []
  // Graphviz emits the line start from the original tip before optional
  // penwidth offset in arrow_type_curve.
  ops.push(DrawOp::Polyline(points=[line_start, q]))
  ops.push(DrawOp::Bezier(filled=false, points=af))
  (q, ops)
}

///|
/// Graphviz parity: dispatch and length factors follow arrows.c arrow_gen_type.
fn arrow_gen_type(
  p : @geom.Point,
  u : @geom.Point,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[DrawOp]) {
  let arrow_type = arrow_type_mask(flag)
  let lenfact = arrow_lenfact(arrow_type)
  let scaled = point(u.x * lenfact * arrowsize, u.y * lenfact * arrowsize)
  match arrow_type {
    ARR_TYPE_NORM => arrow_type_normal(p, scaled, penwidth, flag)
    ARR_TYPE_CROW => arrow_type_crow(p, scaled, arrowsize, penwidth, flag)
    ARR_TYPE_TEE => arrow_type_tee(p, scaled, penwidth, flag)
    ARR_TYPE_BOX => arrow_type_box(p, scaled, penwidth, flag)
    ARR_TYPE_DIAMOND => arrow_type_diamond(p, scaled, penwidth, flag)
    ARR_TYPE_DOT => arrow_type_dot(p, scaled, penwidth, flag)
    ARR_TYPE_CURVE => arrow_type_curve(p, scaled, penwidth, flag)
    ARR_TYPE_GAP => arrow_type_gap(p, scaled)
    _ => arrow_type_normal(p, scaled, penwidth, flag)
  }
}

///|
/// Graphviz parity: arrowhead drawing aligned to refs/graphviz/lib/common/arrows.c.
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
  let flags = parse_arrow_flags(arrowhead)
  if flags.length() == 0 {
    return []
  }
  let mut ux = from.x - tip.x
  let mut uy = from.y - tip.y
  let denom = @math.hypot(ux, uy) + EPSILON
  let scale = ARROW_LENGTH / denom
  let ux_adjust = if ux >= 0.0 { EPSILON } else { -EPSILON }
  let uy_adjust = if uy >= 0.0 { EPSILON } else { -EPSILON }
  ux = ux + ux_adjust
  uy = uy + uy_adjust
  let u = point(ux * scale, uy * scale)
  let ops : Array[DrawOp] = []
  let mut p = tip
  for flag in flags {
    let (next, segment) = arrow_gen_type(p, u, size, penwidth, flag)
    for op in segment {
      ops.push(op)
    }
    p = next
  }
  ops
}
