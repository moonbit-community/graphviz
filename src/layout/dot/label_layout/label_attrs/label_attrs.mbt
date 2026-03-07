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
  let sb = StringBuilder::new()
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
    numbers.push(@numeric.parse_double_or(token.to_string(), 0.0))
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
    return Some({ x_in: val, y_in: val })
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some({ x_in: x, y_in: y })
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
pub fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) => if value == "\\N" { node.name() } else { value }
    None => node.name()
  }
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
  { pad_x_pt, pad_y_pt }
}
