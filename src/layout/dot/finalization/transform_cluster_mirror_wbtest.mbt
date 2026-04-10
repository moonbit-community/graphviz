// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "apply_cluster_lr_mirror_after_rotation falls back to BT mirror for single-cluster LR layouts" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let node = cluster.node("n")

  let rotated = transform_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[transform_make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      transform_make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 30.0, ury: 50.0 },
        label_pos=Some({ x: 15.0, y: 48.0 }),
      ),
    ],
  )

  let mirrored = apply_cluster_lr_mirror_after_rotation({
    graph,
    rankdir: RankDir::LR,
    rotated,
    pre_rotation_bbox: { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    rank_bbox: { llx: 0.0, lly: 0.0, urx: 50.0, ury: 40.0 },
    subgraph_base_bbox: { llx: 0.0, lly: 0.0, urx: 50.0, ury: 40.0 },
  })

  assert_eq(mirrored.bbox, rotated.bbox)
  assert_eq(mirrored.nodes[0].pos, { x: 20.0, y: 70.0 })
  assert_eq(mirrored.subgraphs[0].bbox, {
    llx: 10.0,
    lly: 50.0,
    urx: 30.0,
    ury: 80.0,
  })
  assert_eq(mirrored.subgraphs[0].label_pos, Some({ x: 15.0, y: 52.0 }))
}

///|
test "apply_cluster_lr_mirror_after_rotation uses point mirror and refreshes cluster labels when subgraph bbox exceeds rank bbox" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let node = cluster.node("n")

  let rotated = transform_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[transform_make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      transform_make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 30.0, ury: 50.0 },
        label_pos=Some({ x: -1.0, y: -1.0 }),
      ),
    ],
  )

  let mirrored = apply_cluster_lr_mirror_after_rotation({
    graph,
    rankdir: RankDir::LR,
    rotated,
    pre_rotation_bbox: { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    rank_bbox: { llx: 10.0, lly: 0.0, urx: 60.0, ury: 80.0 },
    subgraph_base_bbox: { llx: 0.0, lly: 0.0, urx: 70.0, ury: 80.0 },
  })

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let pad = @cluster_geometry.CLUSTER_LABEL_PAD_PT
  let expected_label_pos = @graph_label.graph_label_pos(
    mirrored.subgraphs[0].bbox,
    cluster_metrics.width_pt + pad * 2.0,
    cluster_metrics.height_pt + pad,
    @graph_label.graph_label_loc(cluster),
    @graph_label.graph_label_just(cluster),
  )

  assert_eq(mirrored.bbox, rotated.bbox)
  assert_eq(mirrored.nodes[0].pos, { x: 20.0, y: 40.0 })
  assert_eq(mirrored.subgraphs[0].bbox, {
    llx: 10.0,
    lly: 50.0,
    urx: 30.0,
    ury: 80.0,
  })
  assert_eq(mirrored.subgraphs[0].label_pos, Some(expected_label_pos))
}
