///|
/// Graphviz's mapbool: named booleans or an unsigned decimal prefix.
pub fn graphviz_bool(value : String?) -> Bool {
  guard value is Some(value) else { false }
  let lower = value.to_lower()
  if lower == "true" || lower == "yes" {
    return true
  }
  for ch in value {
    guard ch >= '0' && ch <= '9' else { return false }
    if ch != '0' {
      return true
    }
  }
  false
}
