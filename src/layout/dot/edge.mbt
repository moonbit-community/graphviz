fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  match edge_label_metrics_for_attr(edge, "label", false) {
    Some((width, _height)) => width
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> (Double, Double)? {
  edge_label_metrics_for_attr(edge, "label", false)
}

///|
/// Graphviz parity: edge label font selection aligned to refs/graphviz/lib/common/utils.c
/// (initFontEdgeAttr/initFontLabelEdgeAttr).
/// Do not change behavior without updating fixtures/tests.
fn edge_label_metrics_for_attr(
  edge : @cgraph.Edge,
  attr_name : String,
  use_label_font : Bool,
) -> (Double, Double)? {
  match edge.get_attr(attr_name) {
    Some(text) =>
      if text == "" {
        None
      } else {
        let base_size = @attrs.font_size(edge.get_attr("fontsize"))
        let base_font = @attrs.font_name(edge.get_attr("fontname"))
        let font_size_pt =
          if use_label_font {
          @attrs.font_size(edge.get_attr("labelfontsize"), default=base_size)
        } else {
          base_size
        }
        let font =
          if use_label_font {
          @attrs.font_name(edge.get_attr("labelfontname"), default=base_font)
        } else {
          base_font
        }
        let (width, height) = label_text_dimensions(text, font, font_size_pt)
        Some((width, height))
      }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let mut max_height = 0.0
  match edge_label_metrics_for_attr(edge, "label", false) {
    Some((_width, height)) => if height > max_height { max_height = height }
    None => ()
  }
  match edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some((_width, height)) => if height > max_height { max_height = height }
    None => ()
  }
  match edge_label_metrics_for_attr(edge, "taillabel", true) {
    Some((_width, height)) => if height > max_height { max_height = height }
    None => ()
  }
  max_height
}

///|
/// Graphviz parity: edge label presence aligned to refs/graphviz/lib/dotgen/position.c
/// (hasedge).
/// Do not change behavior without updating fixtures/tests.
fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_width_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        height
      } else {
        width
      }
    None => 0.0
  }
}

///|
fn edge_port_name(port : @cgraph.Port?) -> String? {
  match port {
    Some(value) => value.name
    None => None
  }
}

///|
fn endpoint_port_name(
  node_name : String,
  tail_name : String,
  head_name : String,
  tail_port : String?,
  head_port : String?,
) -> String? {
  if node_name == tail_name {
    tail_port
  } else if node_name == head_name {
    head_port
  } else {
    None
  }
}
