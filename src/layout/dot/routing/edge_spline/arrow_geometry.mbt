///|
/// Arrow domain for edge splines: marker flag parsing, arrow polygons, and
/// clip-length calculation used by spline endpoint trimming.

const ARROW_LENGTH : Double = 10.0

///|
const BITS_PER_ARROW_TYPE : Int = 4

///|
const NUMB_OF_ARROW_HEADS : Int = 4

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
priv struct ArrowShapePolygon {
  endpoint : @geom.Point
  polygon : Array[@geom.Point]
}

///|
fn arrow_type_normal0(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> ArrowShapePolygon {
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
  { endpoint: q, polygon: a }
}

///|
fn arrow_type_crow0(
  p_in : @geom.Point,
  u : @geom.Point,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> ArrowShapePolygon {
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
      let toe_line_join_shape =
        miter_shape(toe_base_left, toe_p, toe_base_right, penwidth)
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
  { endpoint: q, polygon: a }
}

///|
fn arrow_type_diamond0(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> ArrowShapePolygon {
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
  { endpoint: q, polygon: a }
}

///|
fn arrow_length_normal(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  let p = point(0.0, 0.0)
  let u = point(lenfact * arrowsize * ARROW_LENGTH, 0.0)
  let shape = arrow_type_normal0(p, u, penwidth, flag)
  let base1 = shape.polygon[1]
  let base2 = shape.polygon[3]
  let tip = shape.polygon[2]
  let full_length = shape.endpoint.x
  let nominal_length = Double::abs(base1.x - tip.x)
  let nominal_base_width = base2.y - base1.y
  let full_base_width = nominal_base_width * full_length / nominal_length
  let overlap_at_base = penwidth / 2.0
  let length_where_width_is_penwidth = full_length * penwidth / full_base_width
  let overlap_at_tip = length_where_width_is_penwidth
  let overlap = if (flag & ARR_MOD_INV) != 0 {
    overlap_at_tip
  } else {
    overlap_at_base
  }
  full_length - overlap
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
priv struct ArrowMatchResult {
  next : Int
  flag : Int
}

///|
fn arrow_match_name_frag(
  value : String,
  start : Int,
  names : Array[(String, Int)],
  flag : Int,
) -> ArrowMatchResult {
  for pair in names {
    let (name, arrow_flag) = pair
    if has_prefix_at(value, start, name) {
      return { next: start + name.length(), flag: flag | arrow_flag }
    }
  }
  { next: start, flag }
}

///|
fn arrow_match_shape(value : String, start : Int) -> ArrowMatchResult {
  let type_mask = (1 << BITS_PER_ARROW_TYPE) - 1
  let syn_match =
    arrow_match_name_frag(value, start, arrow_synonyms(), ARR_TYPE_NONE)
  if syn_match.next != start {
    return syn_match
  }
  let mut rest = start
  let mut flag = ARR_TYPE_NONE
  while true {
    let next_match =
      arrow_match_name_frag(value, rest, arrow_mods(), flag)
    if next_match.next == rest {
      break
    }
    rest = next_match.next
    flag = next_match.flag
  }
  let name_match =
    arrow_match_name_frag(value, rest, arrow_names(), flag)
  flag = name_match.flag
  rest = name_match.next
  if flag != ARR_TYPE_NONE && (flag & type_mask) == 0 {
    flag = flag | ARR_TYPE_NORM
  }
  { next: rest, flag }
}

///|
/// Graphviz parity: arrow flag parsing aligned to refs/graphviz/lib/common/arrows.c.
/// Do not change behavior without updating fixtures/tests.
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
    let matched = arrow_match_shape(text, idx)
    if matched.flag == ARR_TYPE_NONE {
      return []
    }
    let mut flag = matched.flag
    if flag == ARR_TYPE_GAP && flags.length() == NUMB_OF_ARROW_HEADS - 1 {
      flag = ARR_TYPE_NONE
    }
    if flag == ARR_TYPE_GAP && flags.length() == 0 && matched.next >= text.length() {
      flag = ARR_TYPE_NONE
    }
    if flag != ARR_TYPE_NONE {
      flags.push(flag)
    }
    idx = matched.next
  }
  flags
}

///|
fn arrow_length_generic(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  ignore(penwidth)
  ignore(flag)
  lenfact * arrowsize * ARROW_LENGTH
}

///|
fn arrow_length_tee(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  ignore(flag)
  let nominal_length = lenfact * arrowsize * ARROW_LENGTH
  let mut length = nominal_length
  let polygon_extend_over_polyline_at_start =
    penwidth / 2.0 - (1.0 - 0.6) * nominal_length
  if polygon_extend_over_polyline_at_start > 0.0 {
    length = length + polygon_extend_over_polyline_at_start
  }
  let polygon_extend_over_polyline_at_end =
    penwidth / 2.0 - 0.2 * nominal_length
  if polygon_extend_over_polyline_at_start > 0.0 {
    length = length + polygon_extend_over_polyline_at_end
  }
  length
}

///|
fn arrow_length_box(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  ignore(flag)
  lenfact * arrowsize * ARROW_LENGTH + penwidth / 2.0
}

///|
fn arrow_length_diamond(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  let p = point(0.0, 0.0)
  let u = point(lenfact * arrowsize * ARROW_LENGTH, 0.0)
  let shape = arrow_type_diamond0(p, u, penwidth, flag)
  let base1 = shape.polygon[3]
  let base2 = shape.polygon[1]
  let tip = shape.polygon[2]
  let full_length = shape.endpoint.x / 2.0
  let nominal_length = Double::abs(base1.x - tip.x)
  let nominal_base_width = base2.y - base1.y
  let full_base_width = nominal_base_width * full_length / nominal_length
  let length_where_width_is_penwidth =
    full_length * penwidth / full_base_width
  let overlap_at_tip = length_where_width_is_penwidth
  let overlap = overlap_at_tip
  2.0 * full_length - overlap
}

///|
fn arrow_length_dot(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  ignore(flag)
  lenfact * arrowsize * ARROW_LENGTH + penwidth
}

///|
fn arrow_length_curve(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  ignore(flag)
  lenfact * arrowsize * ARROW_LENGTH + penwidth / 2.0
}

///|
fn arrow_length_crow(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  let p = point(0.0, 0.0)
  let u = point(lenfact * arrowsize * ARROW_LENGTH, 0.0)
  let shape = arrow_type_crow0(p, u, arrowsize, penwidth, flag)
  let base1 = shape.polygon[1]
  let base2 = shape.polygon[7]
  let tip = shape.polygon[0]
  let shaft1 = shape.polygon[3]
  let full_length = shape.endpoint.x
  let full_length_without_shaft = full_length - (base1.x - shaft1.x)
  let nominal_length = Double::abs(base1.x - tip.x)
  let nominal_base_width = base2.y - base1.y
  let full_base_width =
    nominal_base_width * full_length_without_shaft / nominal_length
  let overlap_at_base = penwidth / 2.0
  let length_where_width_is_penwidth =
    full_length_without_shaft * penwidth / full_base_width
  let overlap_at_tip = length_where_width_is_penwidth
  let overlap = if (flag & ARR_MOD_INV) != 0 {
    overlap_at_base
  } else {
    overlap_at_tip
  }
  full_length - overlap
}

///|
fn arrow_length_for_flags(
  flags : Array[Int],
  arrowsize : Double,
  penwidth : Double,
) -> Double {
  if arrowsize == 0.0 {
    return 0.0
  }
  let type_mask = (1 << BITS_PER_ARROW_TYPE) - 1
  let mut length = 0.0
  for flag in flags {
    let arrow_type = flag & type_mask
    let delta = match arrow_type {
      ARR_TYPE_NORM => arrow_length_normal(1.0, arrowsize, penwidth, flag)
      ARR_TYPE_CROW => arrow_length_crow(1.0, arrowsize, penwidth, flag)
      ARR_TYPE_TEE => arrow_length_tee(0.5, arrowsize, penwidth, flag)
      ARR_TYPE_BOX => arrow_length_box(1.0, arrowsize, penwidth, flag)
      ARR_TYPE_DIAMOND => arrow_length_diamond(1.2, arrowsize, penwidth, flag)
      ARR_TYPE_DOT => arrow_length_dot(0.8, arrowsize, penwidth, flag)
      ARR_TYPE_CURVE => arrow_length_curve(1.0, arrowsize, penwidth, flag)
      ARR_TYPE_GAP => arrow_length_generic(0.5, arrowsize, penwidth, flag)
      _ => 0.0
    }
    length = length + delta
  }
  length
}

///|
fn arrow_length_for_attr(
  edge : @cgraph.Edge,
  attr_name : String,
  default_flags : Array[Int],
) -> Double {
  let arrowsize_raw = match edge.get_attr("arrowsize") {
    Some(value) => @numeric.parse_double_or(value, 1.0)
    None => 1.0
  }
  let penwidth_raw = match edge.get_attr("penwidth") {
    Some(value) => @numeric.parse_double_or(value, 1.0)
    None => 1.0
  }
  let arrowsize = if arrowsize_raw < 0.0 { 0.0 } else { arrowsize_raw }
  let penwidth = if penwidth_raw < 0.0 { 0.0 } else { penwidth_raw }
  if arrowsize == 0.0 {
    return 0.0
  }
  let flags = match edge.get_attr(attr_name) {
    Some(value) => parse_arrow_flags(Some(value))
    None => default_flags
  }
  if flags.length() == 0 {
    return 0.0
  }
  arrow_length_for_flags(flags, arrowsize, penwidth)
}

///|
fn arrow_len_with_override(base : Double, override_len : Double?) -> Double {
  match override_len {
    Some(value) =>
      if value > 0.0 && value < base {
      value
    } else {
      base
    }
    None => base
  }
}

pub struct ArrowLengthPair {
  tail : Double
  head : Double
}

///|
/// Graphviz parity: arrow length for spline clipping aligned to
/// refs/graphviz/lib/common/arrows.c.
pub fn arrow_length_for_edge(
  edge : @cgraph.Edge,
  include_tail : Bool,
  include_head : Bool,
  arrow_len_override : Double?,
) -> ArrowLengthPair {
  let tail_len =
    if include_tail {
      arrow_len_with_override(
        arrow_length_for_attr(edge, "arrowtail", [ARR_TYPE_NORM]),
        arrow_len_override,
      )
    } else {
      0.0
    }
  let head_len =
    if include_head {
      arrow_len_with_override(
        arrow_length_for_attr(edge, "arrowhead", [ARR_TYPE_NORM]),
        arrow_len_override,
      )
    } else {
      0.0
    }
  { tail: tail_len, head: head_len }
}

///|
/// Graphviz parity: when route orientation is swapped, arrow attrs are swapped too
/// (refs/graphviz/lib/common/splines.c clip_and_install call path).
fn arrow_length_for_edge_oriented(
  edge : @cgraph.Edge,
  include_tail : Bool,
  include_head : Bool,
  arrow_len_override : Double?,
  swapped : Bool,
) -> ArrowLengthPair {
  if !swapped {
    return arrow_length_for_edge(
      edge,
      include_tail,
      include_head,
      arrow_len_override,
    )
  }
  let tail_len =
    if include_tail {
      arrow_len_with_override(
        arrow_length_for_attr(edge, "arrowhead", [ARR_TYPE_NORM]),
        arrow_len_override,
      )
    } else {
      0.0
    }
  let head_len =
    if include_head {
      arrow_len_with_override(
        arrow_length_for_attr(edge, "arrowtail", [ARR_TYPE_NORM]),
        arrow_len_override,
      )
    } else {
      0.0
    }
  { tail: tail_len, head: head_len }
}

