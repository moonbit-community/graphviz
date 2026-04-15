// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "expand_root_bbox_for_label grows the correct axis for TB and LR layouts" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 20.0 }

  let tb_expected : @geom.Rect = { llx: -2.0, lly: 0.0, urx: 12.0, ury: 26.0 }
  let lr_expected : @geom.Rect = { llx: -5.0, lly: -5.0, urx: 10.0, ury: 25.0 }

  assert_eq(
    expand_root_bbox_for_label(bbox, 14.0, 6.0, LabelLoc::Top, RankDir::TB),
    tb_expected,
  )
  assert_eq(
    expand_root_bbox_for_label(bbox, 30.0, 5.0, LabelLoc::Bottom, RankDir::LR),
    lr_expected,
  )
}

///|
test "apply_root_label_bbox expands the root bbox and places the requested label anchor" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("label", "Root Label")
  root.set_attr("labelloc", "t")
  root.set_attr("labeljust", "l")
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let metrics = match @label_metrics.graph_label_metrics(root) {
    Some(value) => value
    None => fail("expected root label metrics")
  }
  let padded_width = metrics.width_pt +
    @cluster_geometry.CLUSTER_LABEL_PAD_PT * 2.0
  let padded_height = metrics.height_pt + @cluster_geometry.CLUSTER_LABEL_PAD_PT
  let width_diff = if padded_width > 10.0 {
    (padded_width - 10.0) / 2.0
  } else {
    0.0
  }
  let expected_bbox : @geom.Rect = {
    llx: 0.0 - width_diff,
    lly: 0.0,
    urx: 10.0 + width_diff,
    ury: 10.0 + padded_height,
  }
  let expected_pos : @geom.Point = {
    x: expected_bbox.llx + padded_width / 2.0,
    y: expected_bbox.ury - padded_height / 2.0,
  }

  let output = apply_root_label_bbox(root, bbox, RankDir::TB)

  assert_eq(output.bbox, expected_bbox)
  assert_eq(output.label_pos, Some(expected_pos))
  assert_eq(root_label_pos_for_bbox(root, expected_bbox), Some(expected_pos))

  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "Child Label")
  let cluster_output = apply_root_label_bbox(cluster, bbox, RankDir::TB)
  assert_eq(cluster_output.bbox, bbox)
  assert_eq(cluster_output.label_pos, None)
}
