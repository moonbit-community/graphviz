// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "expand_layout_tree_bbox_for_edge_labels expands root bbox for endpoint labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("headlabel", "H")

  let layout = postprocess_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=[
      postprocess_make_edge_layout(
        edge,
        {
          start: None,
          end: None,
          points: [
            { x: 0.0, y: 0.0 },
            { x: 3.0, y: 3.0 },
            { x: 6.0, y: 6.0 },
            { x: 9.0, y: 9.0 },
          ],
        },
        head_label_pos=Some({ x: 20.0, y: 15.0 }),
      ),
    ],
  )
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1

  let expanded = expand_layout_tree_bbox_for_edge_labels(
    layout,
    ranks,
    Map::new(),
  )
  let metrics = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => value
    None => fail("expected head label metrics")
  }

  assert_eq(expanded.bbox.llx, 0.0)
  assert_eq(expanded.bbox.lly, 0.0)
  assert_eq(expanded.bbox.urx, 20.0 + metrics.width / 2.0)
  assert_eq(expanded.bbox.ury, 15.0 + metrics.height / 2.0)
}
