///|
type NodeSize = @dot_shared.NodeSize

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
pub fn edge_swap_ends(
  tail : String,
  head : String,
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Bool {
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => 0
  }
  if head_rank > tail_rank {
    return false
  }
  if head_rank < tail_rank {
    return true
  }
  let tail_order = match order_index.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_order = match order_index.get(head) {
    Some(value) => value
    None => 0
  }
  head_order < tail_order
}

///|
pub fn reverse_spline(spline : @geom.Spline) -> @geom.Spline {
  let reversed : Array[@geom.Point] = []
  let mut idx = spline.points.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(spline.points[idx])
  }
  { start: spline.end, end: spline.start, points: reversed }
}

///|
/// Graphviz parity: parallel edge keys are unordered tail/head + port pairs.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_parallel_key(
  tail : String,
  head : String,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> String {
  let tail_port_key = @edge_identity.port_key(tail_port)
  let head_port_key = @edge_identity.port_key(head_port)
  let a = "\{tail}|\{tail_port_key}"
  let b = "\{head}|\{head_port_key}"
  if a <= b {
    "\{a}|\{b}"
  } else {
    "\{b}|\{a}"
  }
}

///|
pub fn edge_has_sameport_mark(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("samehead") {
    Some(value) => value != ""
    None =>
      match edge.get_attr("sametail") {
        Some(value) => value != ""
        None => false
      }
  }
}

///|
pub fn edge_dir_attr_key(edge : @cgraph.Edge) -> String {
  match edge.get_attr("dir") {
    Some(value) => value.to_lower()
    None => "forward"
  }
}

///|
/// Graphviz parity: remap pass keeps sameport-tagged edges separate from plain
/// parallels while preserving class2 endpoint/port grouping.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_parallel_group_key(edge : @cgraph.Edge) -> String {
  let base =
    edge_parallel_key(
      edge.tail().name(),
      edge.head().name(),
      edge.tail_port(),
      edge.head_port(),
    )
  let sameport_mark = edge_has_sameport_mark(edge)
  if sameport_mark {
    "\{base}|sameport"
  } else {
    "\{base}|plain"
  }
}

///|
pub fn adjust_intercluster_dots(
  points : Array[@geom.Point],
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  head_size : NodeSize,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  if points.length() <= 2 {
    return points
  }
  let last_idx = points.length() - 2
  let head_left = head_anchor.x - head_size.width_pt / 2.0
  let head_right = head_anchor.x + head_size.width_pt / 2.0
  let offset = max_double(2.0, nodesep_pt * 0.5)
  let x = if head_anchor.x >= tail_anchor.x {
    head_left - offset
  } else {
    head_right + offset
  }
  let y = tail_anchor.y + (head_anchor.y - tail_anchor.y) * 0.5
  let adjusted = points.copy()
  adjusted[last_idx] = { x, y }
  adjusted
}

///|
pub fn adjust_intracluster_dots(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() <= 3 {
    return points
  }
  let adjusted = points.copy()
  let last = points.length() - 1
  let mid = points.length() / 2
  let mid_y = (points[0].y + points[last].y) / 2.0
  let left_weight = 0.2
  let right_weight = 0.8
  if points.length() % 2 == 0 {
    let left = mid - 1
    if left > 0 && left < last {
      let avg_y = (points[left - 1].y + points[left + 1].y) / 2.0
      adjusted[left] = {
        x: points[left].x,
        y: points[left].y * (1.0 - left_weight) + avg_y * left_weight,
      }
    }
    if mid > 0 && mid < last {
      adjusted[mid] = {
        x: points[mid].x,
        y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
      }
    }
  } else if mid > 0 && mid < last {
    adjusted[mid] = {
      x: points[mid].x,
      y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
    }
  }
  adjusted
}
