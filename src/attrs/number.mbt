///|
pub fn parse_double(value : String?, fallback : Double) -> Double {
  match value {
    Some(text) =>
      try @strconv.parse_double(text) catch {
        _ => fallback
      } noraise {
        parsed => parsed
      }
    None => fallback
  }
}
