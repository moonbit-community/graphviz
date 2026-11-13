// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
const LINE_SPACING : Double = 1.2

///|
priv struct TextDimensions {
  width : Double
  height : Double
}

///|
fn split_label_lines(
  label : String,
  trim_trailing_break~ : Bool,
) -> Array[String] {
  let lines : Array[String] = []
  let mut sb = StringBuilder()
  let mut escaping = false
  let mut ended_with_break = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        lines.push(sb.to_string())
        sb = StringBuilder()
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
      sb = StringBuilder()
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
/// Graphviz record labels collapse a trailing horizontal-whitespace run to one
/// space before measuring or rendering a text span.
pub fn normalize_label_line_trailing_whitespace(line : String) -> String {
  let trimmed = line.trim_end(chars=" \t")
  if trimmed.length() == line.length() {
    return line
  }
  trimmed.to_owned() + " "
}

///|
fn try_multiline_override(
  label : String,
  font : @text.Font,
  text_context~ : @text_layout.Context,
) -> TextDimensions? {
  let raw_lines = split_label_lines(label, trim_trailing_break=false)
  if raw_lines.length() <= 1 {
    return None
  }
  let lines = split_label_lines(label, trim_trailing_break=true)
  let mut max_width = 0.0
  let mut total_height = 0.0
  // labels.c::storeline truncates the empty-line advance, not font metrics.
  let empty_line_height = (font.size_pt * LINE_SPACING).trunc()
  for line in lines {
    let measurement_line = normalize_label_line_trailing_whitespace(line)
    if measurement_line == "" {
      total_height += empty_line_height
      continue
    }
    match text_context.calibrated_span(font, measurement_line) {
      Some((width, height, _, _)) => {
        max_width = Double::max(max_width, width)
        total_height += height
      }
      None => return None
    }
  }
  Some({ width: max_width, height: total_height, })
}

///|
pub fn label_text_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
  text_context~ : @text_layout.Context,
) -> (Double, Double, Double, Double) {
  if label == "" {
    return (0.0, 0.0, 0.0, 0.0)
  }
  let font : @text.Font = { name: font_name, size_pt: font_size_pt, }
  if text_context.calibrated_span(font, label) is Some(metrics) {
    return metrics
  }
  let (layout_offset, centerline_offset) = text_context.text_offsets(font)
  if try_multiline_override(label, font, text_context~) is Some(dims) {
    return (dims.width, dims.height, layout_offset, centerline_offset)
  }
  let lines = split_label_lines(label, trim_trailing_break=true)
  let mut max_width = 0.0
  let mut total_height = 0.0
  let mut first_height : Double? = None
  let mut uniform_height = true
  for line in lines {
    let metrics = text_context.measure(
      font,
      if line == "" {
        " "
      } else {
        line
      },
    )
    if line != "" {
      max_width = Double::max(max_width, metrics.width_pt)
    }
    total_height += metrics.height_pt
    match first_height {
      None => first_height = Some(metrics.height_pt)
      Some(height) => if height != metrics.height_pt { uniform_height = false }
    }
  }
  if uniform_height && first_height is Some(height) {
    total_height = lines.length().to_double() * height
  }
  (max_width, total_height, layout_offset, centerline_offset)
}

///|
pub fn record_label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
  text_context~ : @text_layout.Context,
) -> (Double, Double) {
  let (width, height, _, _) = label_text_metrics(
    label,
    font_name,
    font_size_pt,
    text_context~,
  )
  (width, height)
}
