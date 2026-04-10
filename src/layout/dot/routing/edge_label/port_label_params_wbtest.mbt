// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "port_label_params applies defaults parse fallback and min clamp" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-999")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-180.0, 2.0)))

  edge.set_attr("labelangle", "oops")
  edge.set_attr("labeldistance", "oops")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 1.0)))
}

///|
test "port_label_params treats empty attrs as explicit defaults only when the other attr is present" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  edge.set_attr("labelangle", "")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-30")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-30.0, 1.0)))
}
