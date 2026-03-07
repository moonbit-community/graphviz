///|
/// Graphviz numeric parsing and rounding helpers shared across dot layout
/// stages, engines, and fixtures.

///|
pub(all) struct GraphSizePt {
  width_pt : Double
  height_pt : Double
}

///|
pub fn parse_double_or(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
/// Graphviz ROUND macro parity (round half away from zero).
pub fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
pub fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn first_numeric_token(value : String) -> String? {
  let sb = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
      seen = true
    } else if seen {
      break
    }
  }
  if seen {
    Some(sb.to_string())
  } else {
    None
  }
}

///|
pub fn parse_first_double(value : String, fallback : Double) -> Double {
  match first_numeric_token(value) {
    Some(token) => parse_double_or(token, fallback)
    None => fallback
  }
}

///|
pub fn parse_first_double_optional(value : String) -> Double? {
  match first_numeric_token(value) {
    Some(token) =>
      try @strconv.parse_double(token) catch {
        _ => None
      } noraise {
        parsed => Some(parsed)
      }
    None => None
  }
}

///|
pub fn parse_attr_double(value : String, fallback : Double, min : Double) -> Double {
  match parse_first_double_optional(value) {
    Some(parsed) => if parsed < min { min } else { parsed }
    None => fallback
  }
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c.
pub fn parse_graph_size_pt_attr(graph : @cgraph.Graph) -> GraphSizePt? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = parse_double_or(parts[0], -1.0)
      let height_in =
        if parts.length() > 1 {
          parse_double_or(parts[1], -1.0)
        } else {
          width_in
        }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some({ width_pt: width_in * 72.0, height_pt: height_in * 72.0 })
    }
    None => None
  }
}
