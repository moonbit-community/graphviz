// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "expand_bbox_for_edge_labels skips flat non-self mid labels without flat-label vnodes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [
      layout_edge(
        edge,
        straight_spline(),
        label_pos=Some(@edge_spline.point(25.0, 25.0)),
      ),
    ],
    ranks: { "a": 0, "b": 0 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, base_bbox)
}

///|
test "expand_bbox_for_edge_labels keeps self-edge mid labels even on the same rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  edge.set_attr("label", "self")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let label_pos = Some(@edge_spline.point(25.0, 25.0))
  let metrics : LabelExtent? = match
    @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => Some({ width: value.width, height: value.height })
    None => fail("expected mid label metrics")
  }

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [layout_edge(edge, straight_spline(), label_pos~)],
    ranks: { "n": 0 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, expand_bbox_for_label_pos(base_bbox, label_pos, metrics))
}

///|
test "expand_bbox_for_edge_labels raises top for flat-label vnode edges in TB" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_pos = Some(@edge_spline.point(25.0, 25.0))
  let edge_layout = layout_edge(edge, straight_spline(), label_pos~)
  let flat_label_edge_vnodes : Map[String, String] = Map::new()
  flat_label_edge_vnodes[@edge_identity.edge_key(edge)] = "v_flat"
  let ranks : Map[String, Int] = { "a": 0, "b": 0 }
  let flags = classify_flat_edge_label(edge, ranks, flat_label_edge_vnodes)
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let mid_bbox = expand_bbox_for_edge_mid_label(
    base_bbox, edge_layout, flags, false,
  )
  let expected = maybe_raise_flat_edge_vnode_bbox_top(
    mid_bbox,
    edge_layout,
    flags,
    @rankdir.RankDir::TB,
    false,
  )

  let output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks,
    flat_label_edge_vnodes,
    rankdir: @rankdir.RankDir::TB,
  })

  assert_eq(output, expected)
  assert_true(output.ury > mid_bbox.ury)
}

///|
test "expand_bbox_for_edge_labels flips endpoint label extent in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("headlabel", "wide-head")
  let base_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  let head_label_pos = Some(@edge_spline.point(25.0, 25.0))
  let edge_layout = layout_edge(edge, straight_spline(), head_label_pos~)
  let metrics : LabelExtent? = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => Some({ width: value.width, height: value.height })
    None => fail("expected head label metrics")
  }

  let tb_output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks: { "a": 0, "b": 1 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::TB,
  })
  let lr_output = expand_bbox_for_edge_labels({
    bbox: base_bbox,
    edges: [edge_layout],
    ranks: { "a": 0, "b": 1 },
    flat_label_edge_vnodes: Map::new(),
    rankdir: @rankdir.RankDir::LR,
  })

  assert_eq(
    tb_output,
    expand_bbox_for_label_pos(
      base_bbox,
      head_label_pos,
      edge_label_extent_for_rankdir(metrics, false),
    ),
  )
  assert_eq(
    lr_output,
    expand_bbox_for_label_pos(
      base_bbox,
      head_label_pos,
      edge_label_extent_for_rankdir(metrics, true),
    ),
  )
  assert_true(tb_output.urx > lr_output.urx)
  assert_true(lr_output.ury > tb_output.ury)
}
