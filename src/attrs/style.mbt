///|
fn style_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch == ',' || ch.is_whitespace() {
      if seen {
        tokens.push(current.to_string())
        current = StringBuilder::new()
        seen = false
      }
    } else {
      current.write_char(ch)
      seen = true
    }
  }
  if seen {
    tokens.push(current.to_string())
  }
  tokens
}

///|
pub fn parse_style(value : String?, default? : String = "solid") -> StyleFlags {
  let raw = match value {
    Some(text) => if text == "" { default } else { text }
    None => default
  }
  let lowered = raw.to_lower()
  let tokens = style_tokens(lowered)
  let mut filled = false
  let mut dashed = false
  let mut dotted = false
  for token in tokens {
    match token {
      "filled" => filled = true
      "dashed" => dashed = true
      "dotted" => dotted = true
      _ => ()
    }
  }
  { raw: lowered, filled, dashed, dotted }
}
