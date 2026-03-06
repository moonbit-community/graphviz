///|
/// Xlabel dimension metrics and rankdir-flip helpers shared by candidate,
/// update, and finalization stages.

priv struct XLabelMetrics {
  width : Double
  height : Double
}

priv struct LabelDims {
  width : Double
  height : Double
}


fn xlabel_metrics_for_node(node : @cgraph.Node) -> XLabelMetrics? {
  match node.get_attr("xlabel") {
    Some(text) =>
      if text == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
        let font = @attrs.font_name(node.get_attr("fontname"))
        let (width, height) = label_text_dimensions(text, font, font_size_pt)
        Some({ width, height })
      }
    None => None
  }
}

fn xlabel_metrics_for_edge(edge : @cgraph.Edge) -> XLabelMetrics? {
  match edge_label_metrics_for_attr(edge, "xlabel", false) {
    Some(metrics) => Some({ width: metrics.width, height: metrics.height })
    None => None
  }
}

fn maybe_flip_dims(
  width : Double,
  height : Double,
  flip : Bool,
) -> LabelDims {
  if flip {
    { width: height, height: width }
  } else {
    { width, height }
  }
}
