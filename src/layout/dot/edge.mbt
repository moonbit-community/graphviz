fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
priv struct EdgeLabelMetrics {
  width : Double
  height : Double
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  match edge_label_metrics_for_attr(edge, "label", false) {
    Some(metrics) => metrics.width
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> EdgeLabelMetrics? {
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
) -> EdgeLabelMetrics? {
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
        Some({ width, height })
      }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let mut max_height = 0.0
  match edge_label_metrics_for_attr(edge, "label", false) {
    Some(metrics) => if metrics.height > max_height { max_height = metrics.height }
    None => ()
  }
  match edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(metrics) => if metrics.height > max_height { max_height = metrics.height }
    None => ()
  }
  match edge_label_metrics_for_attr(edge, "taillabel", true) {
    Some(metrics) => if metrics.height > max_height { max_height = metrics.height }
    None => ()
  }
  max_height
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if @dot_shared.edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_width_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.height
      } else {
        metrics.width
      }
    None => 0.0
  }
}

///|
fn self_edge_label_height_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.width
      } else {
        metrics.height
      }
    None => 0.0
  }
}
