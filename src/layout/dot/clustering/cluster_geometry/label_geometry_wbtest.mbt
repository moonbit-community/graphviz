// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "cluster_label_padding_for_layout and width follow label metrics on vertical layouts" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let top = root.subgraph(name="cluster_top")
  top.set_attr("label", "Top Label")
  let top_metrics = match @label_metrics.graph_label_metrics(top) {
    Some(value) => value
    None => fail("expected top cluster label metrics")
  }

  let top_padding = cluster_label_padding_for_layout(top, RankDir::TB)
  assert_eq(top_padding.top, top_metrics.height_pt + CLUSTER_LABEL_PAD_PT)
  assert_eq(top_padding.bottom, 0.0)
  assert_eq(
    cluster_label_width_with_pad_for_layout(top),
    Some(top_metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0),
  )

  let bottom = root.subgraph(name="cluster_bottom")
  bottom.set_attr("label", "Bottom Label")
  bottom.set_attr("labelloc", "b")
  let bottom_metrics = match @label_metrics.graph_label_metrics(bottom) {
    Some(value) => value
    None => fail("expected bottom cluster label metrics")
  }
  let bottom_padding = cluster_label_padding_for_layout(bottom, RankDir::BT)
  assert_eq(bottom_padding.top, 0.0)
  assert_eq(
    bottom_padding.bottom,
    bottom_metrics.height_pt + CLUSTER_LABEL_PAD_PT,
  )

  let unlabeled = root.subgraph(name="cluster_empty")
  let empty_padding = cluster_label_padding_for_layout(unlabeled, RankDir::TB)
  assert_eq(empty_padding.top, 0.0)
  assert_eq(empty_padding.bottom, 0.0)
  assert_eq(cluster_label_width_with_pad_for_layout(unlabeled), None)
}

///|
test "cluster_label_borders_for_xpos_constraints only apply on flipped layouts" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let top = root.subgraph(name="cluster_top")
  top.set_attr("label", "Top Label")
  let top_metrics = match @label_metrics.graph_label_metrics(top) {
    Some(value) => value
    None => fail("expected top cluster label metrics")
  }
  let top_border = top_metrics.height_pt + CLUSTER_LABEL_PAD_PT

  assert_eq(
    cluster_label_borders_for_xpos_constraints(top, RankDir::TB),
    (0.0, 0.0),
  )
  assert_eq(
    cluster_label_borders_for_xpos_constraints(top, RankDir::LR),
    (0.0, top_border),
  )

  let bottom = root.subgraph(name="cluster_bottom")
  bottom.set_attr("label", "Bottom Label")
  bottom.set_attr("labelloc", "bottom")
  let bottom_metrics = match @label_metrics.graph_label_metrics(bottom) {
    Some(value) => value
    None => fail("expected bottom cluster label metrics")
  }
  let bottom_border = bottom_metrics.height_pt + CLUSTER_LABEL_PAD_PT
  assert_eq(
    cluster_label_borders_for_xpos_constraints(bottom, RankDir::RL),
    (bottom_border, 0.0),
  )

  let unlabeled = root.subgraph(name="cluster_empty")
  assert_eq(
    cluster_label_borders_for_xpos_constraints(unlabeled, RankDir::LR),
    (0.0, 0.0),
  )
}

///|
test "expand_cluster_label_bbox_for_position_stage grows the label side and width symmetrically" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let top = root.subgraph(name="cluster_top")
  top.set_attr("label", "Top Label")
  let top_metrics = match @label_metrics.graph_label_metrics(top) {
    Some(value) => value
    None => fail("expected top cluster label metrics")
  }
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 20.0 }
  let top_width = top_metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0
  let top_extra = if top_width > 10.0 { (top_width - 10.0) / 2.0 } else { 0.0 }
  let top_expected : @geom.Rect = {
    llx: 0.0 - top_extra,
    lly: 0.0,
    urx: 10.0 + top_extra,
    ury: 20.0 + top_metrics.height_pt + CLUSTER_LABEL_PAD_PT,
  }
  assert_eq(
    expand_cluster_label_bbox_for_position_stage(top, bbox),
    top_expected,
  )

  let bottom = root.subgraph(name="cluster_bottom")
  bottom.set_attr("label", "Bottom Label")
  bottom.set_attr("labelloc", "b")
  let bottom_metrics = match @label_metrics.graph_label_metrics(bottom) {
    Some(value) => value
    None => fail("expected bottom cluster label metrics")
  }
  let bottom_width = bottom_metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0
  let bottom_extra = if bottom_width > 10.0 {
    (bottom_width - 10.0) / 2.0
  } else {
    0.0
  }
  let bottom_expected : @geom.Rect = {
    llx: 0.0 - bottom_extra,
    lly: 0.0 - bottom_metrics.height_pt - CLUSTER_LABEL_PAD_PT,
    urx: 10.0 + bottom_extra,
    ury: 20.0,
  }
  assert_eq(
    expand_cluster_label_bbox_for_position_stage(bottom, bbox),
    bottom_expected,
  )

  let unlabeled = root.subgraph(name="cluster_empty")
  assert_eq(expand_cluster_label_bbox_for_position_stage(unlabeled, bbox), bbox)
}
