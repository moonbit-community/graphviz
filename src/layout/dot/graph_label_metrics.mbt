///|
/// Graphviz parity: graph label text metrics use shared inherited-attribute
/// policy while binding dot-package text measurement implementation.
fn graph_label_metrics(graph : @cgraph.Graph) -> GraphLabelMetrics? {
  @dot_shared.graph_label_metrics_with(graph, label_text_dimensions)
}
