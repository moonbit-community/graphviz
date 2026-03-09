///|
test "compute_root_cluster_padding only applies to root clustered boundary ranks and BT swaps the result" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("margin", "12.5")
  let clustered = root.node("clustered")
  let outside = root.node("outside")
  let cluster = root.subgraph(name="cluster_0")
  ignore(cluster.node("clustered"))

  let ranks : Map[String, Int] = Map::new()
  ranks["clustered"] = 0
  ranks["outside"] = 2

  let padding = compute_root_cluster_padding(
    root,
    [clustered, outside],
    [0, 2],
    ranks,
  )
  assert_eq(padding.root_cluster_pad_top, 12.5)
  assert_eq(padding.root_cluster_pad_bottom, 0.0)
  assert_eq(root_cluster_padding_for_rankdir(RankDir::TB, padding), (12.5, 0.0))
  assert_eq(root_cluster_padding_for_rankdir(RankDir::BT, padding), (0.0, 12.5))

  let non_root_padding = compute_root_cluster_padding(
    cluster,
    [clustered, outside],
    [0, 2],
    ranks,
  )
  assert_eq(non_root_padding.root_cluster_pad_top, 0.0)
  assert_eq(non_root_padding.root_cluster_pad_bottom, 0.0)
}

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
  let padded_width = metrics.width_pt + @cluster_geometry.CLUSTER_LABEL_PAD_PT * 2.0
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

///|
test "apply_root_port_padding and apply_root_margin_x respect root and cluster gating" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 1.0, urx: 10.0, ury: 11.0 }
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("margin", "0.5")
  ignore(root.subgraph(name="cluster_0"))
  let cluster = root.subgraph(name="cluster_1")
  let plain = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  plain.set_attr("margin", "0.5")

  let padded_expected : @geom.Rect = {
    llx: 0.0,
    lly: -1.0,
    urx: 10.0,
    ury: 14.0,
  }
  let margin_expected : @geom.Rect = {
    llx: -36.0,
    lly: 1.0,
    urx: 46.0,
    ury: 11.0,
  }

  assert_eq(
    apply_root_port_padding(root, bbox, RankDir::TB, 2.0, 3.0),
    padded_expected,
  )
  assert_eq(apply_root_port_padding(root, bbox, RankDir::LR, 2.0, 3.0), bbox)
  assert_eq(apply_root_port_padding(cluster, bbox, RankDir::TB, 2.0, 3.0), bbox)

  assert_eq(apply_root_margin_x(root, bbox), margin_expected)
  assert_eq(apply_root_margin_x(plain, bbox), bbox)
}
