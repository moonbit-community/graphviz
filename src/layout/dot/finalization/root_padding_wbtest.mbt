// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "root cluster padding takes the maximum with existing node bounds" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("margin", "12.5")
  let cluster = root.subgraph(name="cluster_0")
  let layout = transform_make_layout_tree(cluster, {
    llx: 10.0,
    lly: 20.0,
    urx: 60.0,
    ury: 80.0,
  })
  let covered = compute_root_cluster_padding(
    root,
    { llx: 0.0, lly: 0.0, urx: 100.0, ury: 100.0, },
    [layout],
  )
  @test.assert_eq(covered.root_cluster_pad_top, 0.0)
  @test.assert_eq(covered.root_cluster_pad_bottom, 0.0)
  let partial = compute_root_cluster_padding(
    root,
    { llx: 0.0, lly: 15.0, urx: 100.0, ury: 84.0, },
    [layout],
  )
  @test.assert_eq(partial.root_cluster_pad_top, 4.0)
  @test.assert_eq(partial.root_cluster_pad_bottom, 3.0)
  let nested = compute_root_cluster_padding(
    cluster,
    { llx: 0.0, lly: 20.0, urx: 100.0, ury: 80.0, },
    [layout],
  )
  @test.assert_eq(nested.root_cluster_pad_top, 0.0)
  @test.assert_eq(nested.root_cluster_pad_bottom, 0.0)
}

///|
test "apply_root_margin_x respects root and cluster gating" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 1.0, urx: 10.0, ury: 11.0, }
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("margin", "0.5")
  ignore(root.subgraph(name="cluster_0"))
  let plain = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  plain.set_attr("margin", "0.5")

  let margin_expected : @geom.Rect = {
    llx: -36.0,
    lly: 1.0,
    urx: 46.0,
    ury: 11.0,
  }

  assert_eq(apply_root_margin_x(root, bbox), margin_expected)
  assert_eq(apply_root_margin_x(plain, bbox), bbox)
}
