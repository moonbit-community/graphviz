///|
/// Public label-metric bridge APIs: simplified text dimensions and graph-label
/// metrics built on top of the package's text measurement owner.

///|
pub fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (width, height, _yoffset_layout, _yoffset_centerline) =
    label_text_metrics(label, font_name, font_size_pt)
  (width, height)
}

///|
/// Graphviz parity: graph label text metrics honor inherited graph font
/// attributes while binding dot label measurement to this package.
pub fn graph_label_metrics(graph : @cgraph.Graph) -> @graph_label.GraphLabelMetrics? {
  @graph_label.graph_label_metrics_with(graph, label_text_dimensions)
}
