///|
/// Shared point parsing/scaling and straight-line spline helpers used by
/// noop/neato layout entry paths.

///|
fn try_parse_double(text : String) -> Double? {
  try @strconv.parse_double(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_numbers(text : String, limit : Int) -> Array[Double] {
  let numbers : Array[Double] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in text {
    if ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '+' ||
      ch == '.' ||
      ch == 'e' ||
      ch == 'E' {
      current.write_char(ch)
      seen = true
      continue
    }
    if seen {
      match try_parse_double(current.to_string()) {
        Some(value) => numbers.push(value)
        None => ()
      }
      if numbers.length() >= limit {
        return numbers
      }
      current = StringBuilder::new()
      seen = false
    }
  }
  if seen {
    match try_parse_double(current.to_string()) {
      Some(value) => numbers.push(value)
      None => ()
    }
  }
  numbers
}

///|
fn parse_point_attr(text : String) -> @geom.Point? {
  let numbers = parse_numbers(text, 2)
  if numbers.length() < 2 {
    None
  } else {
    Some({ x: numbers[0], y: numbers[1] })
  }
}

///|
fn scale_point(point : @geom.Point, factor : Double) -> @geom.Point {
  { x: point.x * factor, y: point.y * factor }
}

///|
fn line_control_points(
  start : @geom.Point,
  end : @geom.Point,
) -> Array[@geom.Point] {
  let control1 : @geom.Point = {
    x: (start.x * 2.0 + end.x) / 3.0,
    y: (start.y * 2.0 + end.y) / 3.0,
  }
  let control2 : @geom.Point = {
    x: (start.x + end.x * 2.0) / 3.0,
    y: (start.y + end.y * 2.0) / 3.0,
  }
  [start, control1, control2, end]
}

///|
fn line_spline(
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> @geom.Spline {
  let start = @dot_shared.clip_to_rect(tail_pos, tail_size, head_pos)
  let end = @dot_shared.clip_to_rect(head_pos, head_size, tail_pos)
  {
    start: Some(start),
    end: Some(end),
    points: line_control_points(start, end),
  }
}
