// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Shared font selection for Canvas measurement and SVG text rendering.
pub struct ResolvedFont {
  family : String
  weight : String?
  stretch : String?
  style : String?
}

///|
fn mapped_family(base_lower : String) -> String? {
  match base_lower {
    "times" => Some("Times,serif")
    "palatino" => Some("Palatino Linotype,serif")
    "newcenturyschlbk" => Some("Century Schoolbook L,serif")
    "helvetica" => Some("Helvetica,sans-Serif")
    "courier" => Some("Courier,monospace")
    "bookman" => Some("URW Bookman L,serif")
    "avantgarde" => Some("URW Gothic L,sans-Serif")
    "zapfchancery" => Some("URW Chancery L,serif")
    "zapfdingbats" => Some("Dingbats,fantasy")
    "symbol" => Some("Symbol,fantasy")
    _ => None
  }
}

///|
pub fn resolve_font(font_name : String) -> ResolvedFont {
  let parts : Array[String] = []
  for part in font_name.split("-") {
    parts.push(part.to_owned())
  }
  if parts.length() == 0 {
    return { family: font_name, weight: None, stretch: None, style: None, }
  }
  let base_lower = parts[0].to_lower()
  let family = match mapped_family(base_lower) {
    Some(mapped) => mapped
    None => {
      let lower = font_name.to_lower()
      if lower == "times-roman" || lower == "times" {
        "Times,serif"
      } else {
        return { family: font_name, weight: None, stretch: None, style: None, }
      }
    }
  }
  let mut weight : String? = None
  let mut stretch : String? = None
  let mut style : String? = None
  let mut has_unknown = false
  for i in 1..<parts.length() {
    let token = parts[i].to_lower()
    match token {
      "bold" => weight = Some("bold")
      "demi" => weight = Some("demi")
      "light" => weight = Some("light")
      "book" => weight = Some("book")
      "medium" => weight = Some("medium")
      "roman" => if base_lower != "times" { weight = Some("roman") }
      "italic" => style = Some("italic")
      "oblique" => style = Some("oblique")
      "narrow" => stretch = Some("condensed")
      "bolditalic" => {
        weight = Some("bold")
        style = Some("italic")
      }
      "boldoblique" => {
        weight = Some("bold")
        style = Some("oblique")
      }
      "lightitalic" => {
        weight = Some("light")
        style = Some("italic")
      }
      "bookoblique" => {
        weight = Some("book")
        style = Some("oblique")
      }
      "demiitalic" => {
        weight = Some("demi")
        style = Some("italic")
      }
      "demioblique" => {
        weight = Some("demi")
        style = Some("oblique")
      }
      "mediumitalic" => {
        weight = Some("medium")
        style = Some("italic")
      }
      _ => has_unknown = true
    }
  }
  if has_unknown {
    return { family: font_name, weight: None, stretch: None, style: None, }
  }
  { family, weight, stretch, style, }
}
