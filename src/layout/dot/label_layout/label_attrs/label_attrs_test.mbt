// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "graph margin parsing uses inches and clamps invalid or negative values" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  assert_eq(graph_margin_x_pt(graph), 0.0)

  graph.set_attr("margin", "0.5")
  assert_eq(graph_margin_x_pt(graph), 36.0)

  graph.set_attr("margin", "0.25,0.75")
  assert_eq(graph_margin_x_pt(graph), 18.0)

  graph.set_attr("margin", "-2,1")
  assert_eq(graph_margin_x_pt(graph), 0.0)

  graph.set_attr("margin", "oops")
  assert_eq(graph_margin_x_pt(graph), 0.0)
}

///|
test "label_text falls back to node name and resolves Graphviz slash-N" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("node_a")

  assert_eq(label_text(node), "node_a")

  node.set_attr("label", "custom")
  assert_eq(label_text(node), "custom")

  node.set_attr("label", "\\N")
  assert_eq(label_text(node), "node_a")
}

///|
test "node_padding uses defaults and margin overrides in points" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let defaults = node_padding(node)
  assert_eq(defaults.pad_x_pt, 16.0)
  assert_eq(defaults.pad_y_pt, 8.0)

  node.set_attr("margin", "0.25")
  let uniform = node_padding(node)
  assert_eq(uniform.pad_x_pt, 36.0)
  assert_eq(uniform.pad_y_pt, 36.0)

  node.set_attr("margin", "0.5,0.125")
  let explicit = node_padding(node)
  assert_eq(explicit.pad_x_pt, 72.0)
  assert_eq(explicit.pad_y_pt, 18.0)

  node.set_attr("margin", "-1,0.25")
  let clamped = node_padding(node)
  assert_eq(clamped.pad_x_pt, 0.0)
  assert_eq(clamped.pad_y_pt, 36.0)

  node.set_attr("margin", "bad")
  let invalid = node_padding(node)
  assert_eq(invalid.pad_x_pt, 16.0)
  assert_eq(invalid.pad_y_pt, 8.0)
}
