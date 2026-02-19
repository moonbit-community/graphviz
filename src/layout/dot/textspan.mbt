///|
/// Graphviz parity: text metrics aligned to refs/graphviz/lib/common/textspan.c
/// + labels.c + label/xlabels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
const LINE_SPACING : Double = 1.2

///|
const TEXT_SCALE : Double = 0.9706

///|
const RECORD_TEXT_SCALE : Double = 0.97036

///|
const TEXT_YOFFSET_CENTERLINE_SCALE : Double = 0.1

///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

const PERIPHERY_GAP_PT : Double = 4.0

///|
// Graphviz keeps edge-label ranks tight; use a fraction of nodesep on label ranks.
const EDGE_LABEL_NODESEP_PT : Double = 5.0

///|
const SELF_EDGE_SIZE_PT : Double = 18.0

///|
const EDGE_LABEL_PAD_WIDTH_PT : Double = 100.0

///|
const EDGE_LABEL_FLAT_SPACE_PT : Double = 6.0

///|
const PORT_LABEL_DISTANCE_PT : Double = 10.0

///|
const GRAPHVIZ_PI : Double = 3.14159265358979323846

///|
const PORT_LABEL_ANGLE_DEG : Double = -25.0

///|
const PORT_LABEL_ANGLE_MIN_DEG : Double = -180.0

///|
const ELLIPSE_LABEL_SCALE : Double = 1.0

///|
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
}

///|
fn is_monospace_font(font_name : String) -> Bool {
  let lower = font_name.to_lower()
  lower.contains("mono") || lower.contains("courier") || lower.contains("fixed")
}

///|
fn line_height_scale(font_name : String, font_size_pt : Double) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.125
  } else if lower.contains("times") {
    let min_size = 10.0
    let max_size = 14.0
    let min_scale = 1.125
    let max_scale = 16.5 / 14.0
    if font_size_pt <= min_size {
      min_scale
    } else if font_size_pt >= max_size {
      max_scale
    } else {
      let t = (font_size_pt - min_size) / (max_size - min_size)
      min_scale + t * (max_scale - min_scale)
    }
  } else {
    LINE_SPACING
  }
}

///|
fn text_line_height(font_name : String, font_size_pt : Double) -> Double {
  font_size_pt * line_height_scale(font_name, font_size_pt)
}

///|
fn char_width_units_base(ch : Char) -> Double {
  if @font_metrics.HAS_FONT_METRICS {
    let code = ch.to_int()
    if code >= 0 && code < @font_metrics.font_metrics.length() {
      let width = @font_metrics.font_metrics[code]
      if width > 0.0 {
        return width
      }
    }
  }
  match ch {
    ' ' => 250
    '\t' => 250
    '!' => 333
    '"' => 408
    '#' => 500
    '$' => 500
    '%' => 833
    '&' => 778
    '\'' => 180
    '(' | ')' | '[' | ']' => 333
    '*' => 500
    '+' | '<' | '=' | '>' => 564
    ',' | '.' => 250
    '-' => 333
    '/' | '\\' => 278
    '0'..='9' => 500
    ':' | ';' => 278
    '?' => 444
    '@' => 921
    'A' => 722
    'B' => 667
    'C' => 667
    'D' => 722
    'E' => 611
    'F' => 556
    'G' => 722
    'H' => 722
    'I' => 333
    'J' => 389
    'K' => 722
    'L' => 611
    'M' => 889
    'N' => 722
    'O' => 722
    'P' => 556
    'Q' => 722
    'R' => 667
    'S' => 556
    'T' => 611
    'U' => 722
    'V' => 722
    'W' => 944
    'X' => 722
    'Y' => 722
    'Z' => 611
    '^' => 469
    '_' => 500
    '`' => 333
    'a' => 444
    'b' => 500
    'c' => 444
    'd' => 500
    'e' => 444
    'f' => 333
    'g' => 500
    'h' => 500
    'i' => 278
    'j' => 278
    'k' => 500
    'l' => 278
    'm' => 778
    'n' => 500
    'o' => 500
    'p' => 500
    'q' => 500
    'r' => 333
    's' => 389
    't' => 278
    'u' => 500
    'v' => 500
    'w' => 722
    'x' => 500
    'y' => 500
    'z' => 444
    '{' => 480
    '|' => 200
    '}' => 480
    '~' => 541
    _ => 500
  }
}

///|
fn char_width_units(ch : Char, uppercase_boost : Bool) -> Double {
  let base = char_width_units_base(ch)
  if @font_metrics.HAS_FONT_METRICS {
    base
  } else if uppercase_boost && ch.is_ascii_uppercase() {
    base + 22.0
  } else if ch.is_ascii_lowercase() {
    base - 2.0
  } else {
    base
  }
}

///|
fn record_char_width_units(ch : Char) -> Double {
  if @font_metrics.HAS_FONT_METRICS {
    return char_width_units_base(ch)
  }
  let base =
    if ch == ' ' {
      276.0
    } else if ch.is_ascii_digit() {
      char_width_units_base(ch) - 4.0
    } else {
      char_width_units_base(ch)
    }
  if ch.is_ascii_lowercase() {
    base - 2.0
  } else {
    base
  }
}

///|
fn char_kerning_units(prev : Char, curr : Char) -> Double {
  if !@font_metrics.HAS_FONT_KERNING {
    return 0.0
  }
  if prev == ' ' && @font_metrics.HAS_SPACE_KERNING {
    let right = curr.to_int()
    if right >= 0 && right < @font_metrics.font_space_kerning.length() {
      return @font_metrics.font_space_kerning[right]
    }
  }
  let left = prev.to_int()
  let right = curr.to_int()
  if left >= 0 && left < 128 && right >= 0 && right < 128 {
    let idx = left * 128 + right
    if idx >= 0 && idx < @font_metrics.font_kerning.length() {
      return @font_metrics.font_kerning[idx]
    }
  }
  0.0
}

///|
fn split_label_lines(
  label : String,
  trim_trailing_break~ : Bool,
) -> Array[String] {
  let lines : Array[String] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut ended_with_break = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        lines.push(sb.to_string())
        sb = StringBuilder::new()
        ended_with_break = true
      } else {
        sb.write_char(ch)
        ended_with_break = false
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      lines.push(sb.to_string())
      sb = StringBuilder::new()
      ended_with_break = true
    } else {
      sb.write_char(ch)
      ended_with_break = false
    }
  }
  if escaping {
    sb.write_char('\\')
    ended_with_break = false
  }
  lines.push(sb.to_string())
  if trim_trailing_break && ended_with_break && lines.length() > 1 {
    ignore(lines.pop())
  }
  lines
}

///|
fn try_multiline_textspan_override(
  label : String,
  font_name : String,
  font_size_pt : Double,
  trim_trailing_break~ : Bool,
) -> (Double, Double)? {
  let lines = split_label_lines(label, trim_trailing_break~)
  if lines.length() <= 1 {
    return None
  }
  let mut max_width = 0.0
  let mut total_height = 0.0
  // Graphviz labels.c::storeline uses integer-truncated fontsize*LINESPACING
  // for empty lines, while non-empty lines use renderer-provided span height.
  let empty_line_height = (font_size_pt * LINE_SPACING).trunc()
  for line in lines {
    if line == "" {
      total_height = total_height + empty_line_height
      continue
    }
    match @font_metrics.lookup_textspan_override(line, font_name, font_size_pt) {
      Some((width, height)) => {
        if width > max_width {
          max_width = width
        }
        total_height = total_height + height
      }
      None => return None
    }
  }
  Some((max_width, total_height))
}

///|
pub fn label_text_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double, Double, Double) {
  if label == "" {
    return (0.0, 0.0, 0.0, 0.0)
  }
  match @font_metrics.lookup_textspan_metrics(
    label,
    font_name,
    font_size_pt,
  ) {
    Some((width, height, yoffset_layout, yoffset_centerline)) =>
      return (width, height, yoffset_layout, yoffset_centerline)
    None => ()
  }
  match try_multiline_textspan_override(
    label,
    font_name,
    font_size_pt,
    trim_trailing_break=false,
  ) {
    Some((width, height)) => {
      let (yoffset_layout, yoffset_centerline) =
        match @font_metrics.lookup_textspan_offsets(font_name, font_size_pt) {
          Some((layout, centerline)) => (layout, centerline)
          None => (0.0, font_size_pt * TEXT_YOFFSET_CENTERLINE_SCALE)
        }
      return (width, height, yoffset_layout, yoffset_centerline)
    }
    None => ()
  }
  let line_height = text_line_height(font_name, font_size_pt)
  if is_monospace_font(font_name) {
    let mut max_cols = 0
    let mut cols = 0
    let mut lines = 1
    let mut escaping = false
    for ch in label {
      if escaping {
        escaping = false
        if ch == 'n' || ch == 'l' || ch == 'r' {
          if cols > max_cols {
            max_cols = cols
          }
          cols = 0
          lines = lines + 1
        } else {
          cols = cols + 1
        }
        continue
      }
      if ch == '\\' {
        escaping = true
        continue
      }
      if ch == '\n' || ch == '\r' {
        if cols > max_cols {
          max_cols = cols
        }
        cols = 0
        lines = lines + 1
      } else {
        cols = cols + 1
      }
    }
    if escaping {
      cols = cols + 1
    }
    if cols > max_cols {
      max_cols = cols
    }
    let width_units = char_width_units_base('0')
    let width_scale = font_width_scale(font_name)
    let text_scale =
      if @font_metrics.HAS_FONT_METRICS { 1.0 } else { TEXT_SCALE }
    let width_pt = max_cols.to_double() *
      width_units *
      font_size_pt *
      text_scale *
      width_scale /
      1000.0
    let height_pt = lines.to_double() * line_height
    let (yoffset_layout, yoffset_centerline) =
      match @font_metrics.lookup_textspan_offsets(font_name, font_size_pt) {
        Some((layout, centerline)) => (layout, centerline)
        None => (0.0, font_size_pt * TEXT_YOFFSET_CENTERLINE_SCALE)
      }
    return (width_pt, height_pt, yoffset_layout, yoffset_centerline)
  }
  let mut has_lowercase = false
  let mut scan_escape = false
  for ch in label {
    if scan_escape {
      scan_escape = false
      if ch != 'n' && ch != 'l' && ch != 'r' && ch.is_ascii_lowercase() {
        has_lowercase = true
        break
      }
      continue
    }
    if ch == '\\' {
      scan_escape = true
      continue
    }
    if ch.is_ascii_lowercase() {
      has_lowercase = true
      break
    }
  }
  let uppercase_boost = !has_lowercase
  let mut max_units = 0.0
  let mut current_units = 0.0
  let mut lines = 1
  let mut escaping = false
  let mut prev_char : Char? = None
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
        prev_char = None
      } else {
        match prev_char {
          Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
          None => ()
        }
        current_units = current_units + char_width_units(ch, uppercase_boost)
        prev_char = Some(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      if current_units > max_units {
        max_units = current_units
      }
      current_units = 0
      lines = lines + 1
      prev_char = None
    } else {
      match prev_char {
        Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
        None => ()
      }
      current_units = current_units + char_width_units(ch, uppercase_boost)
      prev_char = Some(ch)
    }
  }
  if escaping {
    let ch = '\\'
    match prev_char {
      Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
      None => ()
    }
    current_units = current_units + char_width_units('\\', uppercase_boost)
    prev_char = Some('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_scale = font_width_scale(font_name)
  let text_scale = if @font_metrics.HAS_FONT_METRICS { 1.0 } else { TEXT_SCALE }
  let width_pt = max_units *
    font_size_pt *
    text_scale *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  let (yoffset_layout, yoffset_centerline) =
    match @font_metrics.lookup_textspan_offsets(font_name, font_size_pt) {
      Some((layout, centerline)) => (layout, centerline)
      None => (0.0, font_size_pt * TEXT_YOFFSET_CENTERLINE_SCALE)
    }
  (width_pt, height_pt, yoffset_layout, yoffset_centerline)
}

///|
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (width, height, _yoffset_layout, _yoffset_centerline) =
    label_text_metrics(label, font_name, font_size_pt)
  (width, height)
}

///|
pub fn record_label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  match @font_metrics.lookup_textspan_override(
    label,
    font_name,
    font_size_pt,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  match try_multiline_textspan_override(
    label,
    font_name,
    font_size_pt,
    trim_trailing_break=true,
  ) {
    Some((width, height)) => return (width, height)
    None => ()
  }
  let line_height = text_line_height(font_name, font_size_pt)
  if is_monospace_font(font_name) {
    let mut max_cols = 0
    let mut cols = 0
    let mut lines = 1
    let mut escaping = false
    let mut ended_with_break = false
    for ch in label {
      if escaping {
        escaping = false
        if ch == 'n' || ch == 'l' || ch == 'r' {
          if cols > max_cols {
            max_cols = cols
          }
          cols = 0
          lines = lines + 1
          ended_with_break = true
        } else {
          cols = cols + 1
          ended_with_break = false
        }
        continue
      }
      if ch == '\\' {
        escaping = true
        continue
      }
      if ch == '\n' || ch == '\r' {
        if cols > max_cols {
          max_cols = cols
        }
        cols = 0
        lines = lines + 1
        ended_with_break = true
      } else {
        cols = cols + 1
        ended_with_break = false
      }
    }
    if escaping {
      cols = cols + 1
      ended_with_break = false
    }
    if cols > max_cols {
      max_cols = cols
    }
    if ended_with_break && lines > 1 {
      lines = lines - 1
    }
    let width_units = record_char_width_units('0')
    let width_scale = font_width_scale(font_name)
    let text_scale =
      if @font_metrics.HAS_FONT_METRICS { 1.0 } else { RECORD_TEXT_SCALE }
    let width_pt = max_cols.to_double() *
      width_units *
      font_size_pt *
      text_scale *
      width_scale /
      1000.0
    let height_pt = lines.to_double() * line_height
    return (width_pt, height_pt)
  }
  let mut max_units = 0.0
  let mut current_units = 0.0
  let mut lines = 1
  let mut escaping = false
  let mut ended_with_break = false
  let mut prev_char : Char? = None
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
        ended_with_break = true
        prev_char = None
      } else {
        match prev_char {
          Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
          None => ()
        }
        current_units = current_units + record_char_width_units(ch)
        ended_with_break = false
        prev_char = Some(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      if current_units > max_units {
        max_units = current_units
      }
      current_units = 0
      lines = lines + 1
      ended_with_break = true
      prev_char = None
    } else {
      match prev_char {
        Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
        None => ()
      }
      current_units = current_units + record_char_width_units(ch)
      ended_with_break = false
      prev_char = Some(ch)
    }
  }
  if escaping {
    let ch = '\\'
    match prev_char {
      Some(prev) => current_units = current_units + char_kerning_units(prev, ch)
      None => ()
    }
    current_units = current_units + record_char_width_units(ch)
    ended_with_break = false
    prev_char = Some('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  if ended_with_break && lines > 1 {
    lines = lines - 1
  }
  let width_scale = font_width_scale(font_name)
  let text_scale =
    if @font_metrics.HAS_FONT_METRICS { 1.0 } else { RECORD_TEXT_SCALE }
  let width_pt = max_units *
    font_size_pt *
    text_scale *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  (width_pt, height_pt)
}
