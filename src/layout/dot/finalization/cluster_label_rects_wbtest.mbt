// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "collect_cluster_label_rects recurses and skips unlabeled subgraphs" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "cluster")
  let nested = cluster.subgraph(name="cluster_1")
  nested.set_attr("label", "nested")
  let plain = root.subgraph(name="group_0")

  let cluster_layout = postprocess_make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 20.0, y: 30.0 }),
    subgraphs=[
      postprocess_make_layout_tree(
        nested,
        { llx: 0.0, lly: 0.0, urx: 8.0, ury: 8.0 },
        label_pos=Some({ x: 40.0, y: 50.0 }),
      ),
    ],
  )
  let plain_layout = postprocess_make_layout_tree(
    plain,
    { llx: 0.0, lly: 0.0, urx: 5.0, ury: 5.0 },
    label_pos=Some({ x: 60.0, y: 70.0 }),
  )

  let rects = collect_cluster_label_rects([cluster_layout, plain_layout], 3.0)

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let nested_metrics = match @label_metrics.graph_label_metrics(nested) {
    Some(value) => value
    None => fail("expected nested label metrics")
  }
  let expected_cluster = rect_from_center(
    { x: 20.0, y: 30.0 },
    cluster_metrics.width_pt,
    cluster_metrics.height_pt,
    3.0,
  )
  let expected_nested = rect_from_center(
    { x: 40.0, y: 50.0 },
    nested_metrics.width_pt,
    nested_metrics.height_pt,
    3.0,
  )

  assert_eq(rects, [expected_cluster, expected_nested])
}
