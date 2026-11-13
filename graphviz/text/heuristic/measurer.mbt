// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub enum Heuristic {
  Builtin
}

///|
pub fn Heuristic::new() -> Heuristic {
  Builtin
}

///|
pub extend Heuristic with @text.Measurer::{measure}

///|
fn font_width_scale(font_name : String) -> Double {
  if font_name.to_lower().contains("palatino") {
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
  } else if lower.contains("helvetica") || lower.contains("doxfont") {
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
    1.2
  }
}

///|
fn char_width_units(ch : Char) -> Double {
  let code = ch.to_int()
  if code >= 0 && code < @font_metrics.font_metrics.length() {
    let width = @font_metrics.font_metrics[code]
    if width > 0.0 {
      return width
    }
  }
  match ch {
    ' ' | '\t' => 250
    '!' => 333
    '"' => 408
    '#' | '$' => 500
    '%' => 833
    '&' => 778
    '\'' => 180
    '(' | ')' | '[' | ']' => 333
    '*' => 500
    '+' | '<' | '=' | '>' => 564
    ',' | '.' => 250
    '-' => 333
    '/' | '\\' => 278
    '0'..<='9' => 500
    ':' | ';' => 278
    '?' => 444
    '@' => 921
    'A' => 722
    'B' | 'C' => 667
    'D' => 722
    'E' => 611
    'F' => 556
    'G' | 'H' => 722
    'I' => 333
    'J' => 389
    'K' => 722
    'L' => 611
    'M' => 889
    'N' | 'O' => 722
    'P' => 556
    'Q' => 722
    'R' => 667
    'S' => 556
    'T' => 611
    'U' | 'V' => 722
    'W' => 944
    'X' | 'Y' => 722
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
    'g' | 'h' => 500
    'i' | 'j' => 278
    'k' => 500
    'l' => 278
    'm' => 778
    'n' | 'o' | 'p' | 'q' => 500
    'r' => 333
    's' => 389
    't' => 278
    'u' | 'v' => 500
    'w' => 722
    'x' | 'y' => 500
    'z' => 444
    '{' | '}' => 480
    '|' => 200
    '~' => 541
    _ => 500
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
    return @font_metrics.font_kerning[left * 128 + right]
  }
  0.0
}

///|
pub impl @text.Measurer for Heuristic with fn measure(_self, font, text) {
  let mut units = 0.0
  if is_monospace_font(font.name) {
    let mut columns = 0
    for _ in text {
      columns += 1
    }
    units = columns.to_double() * char_width_units('0')
  } else {
    let mut previous : Char? = None
    for ch in text {
      if previous is Some(prev) {
        units += char_kerning_units(prev, ch)
      }
      units += char_width_units(ch)
      previous = Some(ch)
    }
  }
  let height_pt = font.size_pt * line_height_scale(font.name, font.size_pt)
  let ascent_pt = @font_metrics.lookup_textspan_offsets(font.name, font.size_pt).map_or(
    0.0,
    offsets => offsets.0,
  )
  {
    width_pt: units * font.size_pt * font_width_scale(font.name) / 1000.0,
    height_pt,
    ascent_pt,
    descent_pt: height_pt - ascent_pt,
    ink: None,
  }
}

///|
/// Select the existing Graphviz reference calibration along with the heuristic
/// provider. Canvas users neither import nor initialize this data.
pub fn context() -> @text_layout.Context {
  @text_layout.Context::new(
    Heuristic::new(),
    calibration=Some({
      span: (font, text) => {
        @font_metrics.lookup_textspan_metrics(text, font.name, font.size_pt)
      },
      offsets: font => {
        @font_metrics.lookup_textspan_offsets(font.name, font.size_pt)
      },
      centered_x: font_name => {
        let lower = font_name.to_lower()
        if lower.contains("avantgarde") || lower.contains("palatino") {
          0.0000001
        } else {
          0.0
        }
      },
    }),
  )
}
