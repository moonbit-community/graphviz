// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Public label-metric bridge APIs: simplified text dimensions and graph-label
/// metrics built on top of the package's text measurement owner.

///|
pub fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (width, height, _yoffset_layout, _yoffset_centerline) = label_text_metrics(
    label, font_name, font_size_pt,
  )
  (width, height)
}

///|
/// Graph and cluster labels preserve HTML syntax and inherited font attributes.
pub fn graph_label_metrics(
  graph : @cgraph.Graph,
) -> @graph_label.GraphLabelMetrics? {
  let html = graph
    .get_attr_value("label")
    .map(value => value is @cgraph.AttrValue::Html(_))
  @graph_label.graph_label_metrics_with(graph, (text, font, size) => {
    guard parse_html_label_cached(text, html~) is Some(label) else {
      return label_text_dimensions(text, font, size)
    }
    let dimensions = html_label_size(label, font, size)
    (dimensions.width_pt, dimensions.height_pt)
  })
}
