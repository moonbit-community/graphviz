///|
pub fn color(value : String?, default? : String = "black") -> String {
  match value {
    Some(text) => if text == "" { default } else { text }
    None => default
  }
}

///|
fn tokenize_color(value : String) -> Array[String] {
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
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

///|
fn append_hex_byte(sb : StringBuilder, value : Int) -> Unit {
  let mut channel = value
  if channel < 0 {
    channel = 0
  } else if channel > 255 {
    channel = 255
  }
  let hi = channel / 16
  let lo = channel % 16
  sb.write_char(hex_digit(hi))
  sb.write_char(hex_digit(lo))
}

///|
fn hsv_to_rgb_hex(h : Double, s : Double, v : Double) -> String {
  let hue = h - h.floor()
  let sat = if s < 0.0 { 0.0 } else if s > 1.0 { 1.0 } else { s }
  let val = if v < 0.0 { 0.0 } else if v > 1.0 { 1.0 } else { v }
  let (r, g, b) =
    if sat <= 0.0 {
      (val, val, val)
    } else {
      let hh = hue * 6.0
      let i = hh.floor().to_int()
      let f = hh - i.to_double()
      let p = val * (1.0 - sat)
      let q = val * (1.0 - sat * f)
      let t = val * (1.0 - sat * (1.0 - f))
      match i % 6 {
        0 => (val, t, p)
        1 => (q, val, p)
        2 => (p, val, t)
        3 => (p, q, val)
        4 => (t, p, val)
        _ => (val, p, q)
      }
    }
  let sb = StringBuilder::new()
  sb.write_char('#')
  append_hex_byte(sb, (r * 255.0).floor().to_int())
  append_hex_byte(sb, (g * 255.0).floor().to_int())
  append_hex_byte(sb, (b * 255.0).floor().to_int())
  sb.to_string()
}

///|
fn normalize_hsv_color(value : String) -> String? {
  let tokens = tokenize_color(value)
  if tokens.length() != 3 {
    return None
  }
  let h = @strconv.parse_double(tokens[0]) catch {
    _ => return None
  }
  let s = @strconv.parse_double(tokens[1]) catch {
    _ => return None
  }
  let v = @strconv.parse_double(tokens[2]) catch {
    _ => return None
  }
  if h < 0.0 || h > 1.0 || s < 0.0 || s > 1.0 || v < 0.0 || v > 1.0 {
    return None
  }
  Some(hsv_to_rgb_hex(h, s, v))
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
    "pink" => "#ffc0cb"
    "hotpink" => "#ff69b4"
    "salmon2" => "#ee8262"
    "deepskyblue" => "#00bfff"
    "goldenrod2" => "#eeb422"
    "burlywood2" => "#eec591"
    "gold1" => "#ffd700"
    "greenyellow" => "#adff2f"
    "darkseagreen" => "#8fbc8f"
    "dodgerblue1" => "#1e90ff"
    "thistle2" => "#eed2ee"
    "darkolivegreen3" => "#a2cd5a"
    "chocolate" => "#d2691e"
    "turquoise3" => "#00c5cd"
    "steelblue3" => "#4f94cd"
    "navy" => "#000080"
    "darkseagreen4" => "#698b69"
    "coral" => "#ff7f50"
    "coral3" => "#cd5b45"
    "blanchedalmond" => "#ffebcd"
    "lightskyblue1" => "#b0e2ff"
    "aquamarine2" => "#76eec6"
    "lemonchiffon" => "#fffacd"
    "darkorange1" => "#ff7f00"
    "lightyellow1" => "#ffffe0"
    "darkorchid4" => "#68228b"
    "lemonchiffon2" => "#eee9bf"
    "goldenrod3" => "#cd9b1d"
    "firebrick" => "#b22222"
    "grey" => "#c0c0c0"
    "gray" => "#c0c0c0"
    "chartreuse4" => "#458b00"
    "bisque4" => "#8b7d6b"
    "mistyrose2" => "#eed5d2"
    "cadetblue1" => "#98f5ff"
    "bisque2" => "#eed5b7"
    "orangered" => "#ff4500"
    "crimson" => "#dc143c"
    "darkolivegreen4" => "#6e8b3d"
    "lightsteelblue1" => "#cae1ff"
    "maroon1" => "#ff34b3"
    "lightgrey" => "#d3d3d3"
    "lightgray" => "#d3d3d3"
    "lightblue" => "#add8e6"
    "purple" => "#a020f0"
    "slateblue" => "#6a5acd"
    "lightblue2" => "#b2dfee"
    _ =>
      match normalize_hsv_color(lower) {
        Some(hex) => hex
        None => lower
      }
  }
}
