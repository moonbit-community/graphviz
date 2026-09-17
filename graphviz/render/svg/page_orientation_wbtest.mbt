// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "rotate overrides orientation and orientation overrides landscape" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("landscape", "true")
  @test.assert_eq(svg_landscape(graph), true)
  graph.set_attr("orientation", "portrait")
  @test.assert_eq(svg_landscape(graph), false)
  graph.set_attr("rotate", "90")
  @test.assert_eq(svg_landscape(graph), true)
  graph.set_attr("rotate", "0")
  graph.set_attr("orientation", "landscape")
  @test.assert_eq(svg_landscape(graph), false)
}
