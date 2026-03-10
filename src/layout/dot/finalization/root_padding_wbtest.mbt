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
