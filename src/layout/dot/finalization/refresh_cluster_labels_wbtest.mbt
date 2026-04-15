// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "refresh_cluster_labels recomputes labeled cluster anchors and leaves others unchanged" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  cluster.set_attr("labelloc", "b")
  cluster.set_attr("labeljust", "r")
  let unlabeled = root.subgraph(name="cluster_1")
  let nested = cluster.subgraph(name="cluster_2")
  nested.set_attr("label", "Nested")

  let layout = transform_make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    subgraphs=[
      transform_make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 50.0, ury: 60.0 },
        label_pos=Some({ x: -1.0, y: -1.0 }),
        subgraphs=[
          transform_make_layout_tree(
            nested,
            { llx: 14.0, lly: 26.0, urx: 32.0, ury: 42.0 },
            label_pos=Some({ x: -2.0, y: -2.0 }),
          ),
        ],
      ),
      transform_make_layout_tree(
        unlabeled,
        { llx: 60.0, lly: 10.0, urx: 90.0, ury: 30.0 },
        label_pos=Some({ x: 61.0, y: 11.0 }),
      ),
    ],
  )

  let refreshed = refresh_cluster_labels(layout)
  let refreshed_cluster = refreshed.subgraphs[0]
  let refreshed_nested = refreshed_cluster.subgraphs[0]
  let refreshed_unlabeled = refreshed.subgraphs[1]

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let nested_metrics = match @label_metrics.graph_label_metrics(nested) {
    Some(value) => value
    None => fail("expected nested label metrics")
  }
  let pad = @cluster_geometry.CLUSTER_LABEL_PAD_PT
  let expected_cluster_label = @graph_label.graph_label_pos(
    refreshed_cluster.bbox,
    cluster_metrics.width_pt + pad * 2.0,
    cluster_metrics.height_pt + pad,
    @graph_label.graph_label_loc(cluster),
    @graph_label.graph_label_just(cluster),
  )
  let expected_nested_label = @graph_label.graph_label_pos(
    refreshed_nested.bbox,
    nested_metrics.width_pt + pad * 2.0,
    nested_metrics.height_pt + pad,
    @graph_label.graph_label_loc(nested),
    @graph_label.graph_label_just(nested),
  )

  assert_eq(refreshed_cluster.label_pos, Some(expected_cluster_label))
  assert_eq(refreshed_nested.label_pos, Some(expected_nested_label))
  assert_eq(refreshed_unlabeled.label_pos, Some({ x: 61.0, y: 11.0 }))
}
