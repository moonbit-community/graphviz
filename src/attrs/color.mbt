///|
pub fn color(value : String?, default? : String = "black") -> String {
  match value {
    Some(text) => if text == "" { default } else { text }
    None => default
  }
}

///|
pub fn normalize_color(value : String) -> String {
  let lower = value.to_lower()
  if lower.has_prefix("#") {
    return lower
  }
  match lower {
    "black" => "#000000"
    "white" => "#ffffff"
    "red" => "#ff0000"
    "green" => "#00ff00"
    "blue" => "#0000ff"
    "yellow" => "#ffff00"
    "orange" => "#ffa500"
    "cyan" => "#00ffff"
    "magenta" => "#ff00ff"
    "hotpink" => "#ff69b4"
    "lightgrey" => "#d3d3d3"
    "lightgray" => "#d3d3d3"
    "purple" => "#a020f0"
    "slateblue" => "#6a5acd"
    "lightblue2" => "#b2dfee"
    _ => lower
  }
}
