// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "cluster_margin_pt uses default and clamps negative values" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  assert_eq(cluster_margin_pt(graph), CLUSTER_MARGIN_PT)

  graph.set_attr("margin", "12.5")
  assert_eq(cluster_margin_pt(graph), 12.5)

  graph.set_attr("margin", "-3")
  assert_eq(cluster_margin_pt(graph), CLUSTER_MARGIN_PT)

  graph.set_attr("margin", "not-a-number")
  assert_eq(cluster_margin_pt(graph), CLUSTER_MARGIN_PT)
}
