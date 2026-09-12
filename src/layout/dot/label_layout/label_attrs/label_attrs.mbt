// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Label attribute parsing helpers: resolved label text, node padding, and
/// graph margin extraction for dot label layout.

///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

///|
priv struct MarginValues {
  x_in : Double
  y_in : Double
}

///|
pub(all) struct NodePadding {
  pad_x_pt : Double
  pad_y_pt : Double
}

///|
fn extract_numbers(value : String) -> Array[Double] {
  let sb = StringBuilder()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    numbers.push(@numeric.parse_double_or(token.to_owned(), 0.0))
  }
  numbers
}

///|
fn parse_margin(value : String) -> MarginValues? {
  let numbers = extract_numbers(value)
  if numbers.length() == 0 {
    return None
  }
  if numbers.length() == 1 {
    let val = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
    return Some({ x_in: val, y_in: val, })
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some({ x_in: x, y_in: y, })
}

///|
/// Graphviz parity: root graph margin defaults to 0 unless explicitly set.
/// Do not change behavior without updating fixtures/tests.
pub fn graph_margin_x_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some(margins) => margins.x_in * 72.0
        None => 0.0
      }
    None => 0.0
  }
}

///|
fn unescape_simple_label_text(value : String) -> String {
  let chars : Array[Char] = []
  for ch in value {
    chars.push(ch)
  }
  let text = StringBuilder()
  let mut index = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch != '\\' || index + 1 >= chars.length() {
      text.write_char(ch)
      index = index + 1
      continue
    }
    let escaped = chars[index + 1]
    // labels.c/make_simple_label retains these layout escapes for its line
    // splitter, while every other escaped byte is rendered literally.
    if escaped == 'n' || escaped == 'l' || escaped == 'r' {
      text.write_char('\\')
    }
    text.write_char(escaped)
    index = index + 2
  }
  text.to_string()
}

///|
pub fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) =>
      if value == "\\N" {
        node.name()
      } else if node.get_attr_value("label") is Some(@cgraph.AttrValue::Html(_)) {
        value
      } else {
        @attrs.decode_label_entities(value)
      }
    None => node.name()
  }
}

///|
pub fn simple_label_text(node : @cgraph.Node) -> String {
  let label = match node.get_attr("label") {
    Some(value) =>
      if value == "\\N" {
        node.name()
      } else {
        value.replace_all(old="\\N", new=node.name())
      }
    None => node.name()
  }
  @attrs.decode_label_entities(unescape_simple_label_text(label))
}

///|
pub fn node_padding(node : @cgraph.Node) -> NodePadding {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some(margins) => {
          pad_x_pt = margins.x_in * 72.0 * 2.0
          pad_y_pt = margins.y_in * 72.0 * 2.0
        }
        None => ()
      }
    None => ()
  }
  { pad_x_pt, pad_y_pt, }
}
