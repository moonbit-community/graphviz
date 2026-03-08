///|
/// Shared helpers for the root complex integration tests. Keep the parsing,
/// edge sampling, and point-comparison utilities here so the user-facing
/// complex sample tests stay focused on layout assertions.

///|
fn complex_parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn complex_parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 {
    complex_parse_double(parts[0], 0.0)
  } else {
    0.0
  }
  let y = if parts.length() > 1 {
    complex_parse_double(parts[1], 0.0)
  } else {
    0.0
  }
  { x, y }
}

///|
fn complex_node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point? {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => Some(complex_parse_point(value))
        None => None
      }
    None => None
  }
}

///|
fn complex_pos_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps : Double,
) -> Bool {
  let dx = Double::abs(actual.x - expected.x)
  let dy = Double::abs(actual.y - expected.y)
  dx <= eps && dy <= eps
}

///|
fn complex_parse_edge_points(text : String) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = []
  for segment in text.split(";") {
    for token_view in segment.split(" ") {
      let token = token_view.trim(chars=" \n\r\t").to_string()
      if token == "" {
        continue
      }
      let mut cleaned = token
      if cleaned.has_suffix("\\") {
        cleaned = cleaned.unsafe_substring(start=0, end=cleaned.length() - 1)
      }
      if cleaned.has_prefix("\\") {
        cleaned = cleaned.unsafe_substring(start=1, end=cleaned.length())
      }
      cleaned = cleaned.trim(chars=" \n\r\t").to_string()
      if cleaned == "" {
        continue
      }
      if cleaned.has_prefix("s,") || cleaned.has_prefix("e,") {
        continue
      }
      if !cleaned.contains(",") {
        continue
      }
      points.push(complex_parse_point(cleaned))
    }
  }
  points
}

///|
fn complex_find_edge(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
) -> @cgraph.Edge? {
  for edge in graph.edges() {
    if edge.tail().name() == tail && edge.head().name() == head {
      return Some(edge)
    }
  }
  None
}

///|
fn complex_edge_points(edge : @cgraph.Edge) -> Array[@geom.Point] {
  match edge.get_attr("pos") {
    Some(value) => complex_parse_edge_points(value)
    None => []
  }
}

///|
fn complex_edge_label_pos(edge : @cgraph.Edge) -> @geom.Point? {
  match edge.get_attr("lp") {
    Some(value) => Some(complex_parse_point(value))
    None => None
  }
}

///|
fn complex_polyline_length(points : Array[@geom.Point]) -> Double {
  if points.length() < 2 {
    return 0.0
  }
  let mut total = 0.0
  for i in 1..<points.length() {
    let dx = points[i].x - points[i - 1].x
    let dy = points[i].y - points[i - 1].y
    total = total + @math.hypot(dx, dy)
  }
  total
}

///|
fn complex_sample_polyline(
  points : Array[@geom.Point],
  t : Double,
) -> @geom.Point {
  if points.length() == 0 {
    return { x: 0.0, y: 0.0 }
  }
  if points.length() == 1 {
    return points[0]
  }
  let total = complex_polyline_length(points)
  if total <= 0.0 {
    return points[0]
  }
  let target = total * t
  let mut acc = 0.0
  for i in 1..<points.length() {
    let a = points[i - 1]
    let b = points[i]
    let dx = b.x - a.x
    let dy = b.y - a.y
    let seg = @math.hypot(dx, dy)
    if acc + seg >= target {
      let ratio = if seg <= 0.0 { 0.0 } else { (target - acc) / seg }
      return { x: a.x + dx * ratio, y: a.y + dy * ratio }
    }
    acc = acc + seg
  }
  points[points.length() - 1]
}

///|
fn complex_resample_polyline(
  points : Array[@geom.Point],
  count : Int,
) -> Array[@geom.Point] {
  if count <= 0 {
    return []
  }
  if points.length() == 0 {
    return []
  }
  if count == 1 {
    return [points[0]]
  }
  let samples : Array[@geom.Point] = []
  let steps = count - 1
  for i in 0..=steps {
    let t = i.to_double() / steps.to_double()
    samples.push(complex_sample_polyline(points, t))
  }
  samples
}

