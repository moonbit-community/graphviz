///|
pub fn font_name(value : String?, default? : String = "Times-Roman") -> String {
  match value {
    Some(text) => if text == "" { default } else { text }
    None => default
  }
}

///|
pub fn font_size(value : String?, default? : Double = 14.0) -> Double {
  let parsed = parse_double(value, default)
  if parsed <= 0.0 {
    default
  } else {
    parsed
  }
}
