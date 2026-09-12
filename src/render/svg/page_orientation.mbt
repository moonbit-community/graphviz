// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn svg_landscape(graph : @cgraph.Graph) -> Bool {
  if graph.get_attr("rotate") is Some(value) {
    parse_int(value, 0) == 90
  } else if graph.get_attr("orientation") is Some(value) {
    value.to_lower().has_prefix("l")
  } else {
    @attrs.graphviz_bool(graph.get_attr("landscape"))
  }
}
