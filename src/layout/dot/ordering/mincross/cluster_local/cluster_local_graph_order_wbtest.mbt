///|
test "build_cluster_graph_order sorts same-depth clusters by cluster_order and keeps nested clusters after their parents" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_a = root.subgraph(name="cluster_a")
  let plain = root.subgraph(name="plain")
  ignore(plain.subgraph(name="cluster_b"))
  ignore(root.subgraph(name="cluster_c"))
  ignore(cluster_a.subgraph(name="cluster_d"))

  let ordered = build_cluster_graph_order(
    root,
    ["cluster_c", "cluster_b", "cluster_a", "cluster_d"],
    Map::new(),
  )

  assert_eq(ordered.cluster_graphs.length(), 4)
  assert_eq(ordered.cluster_names, [
    "cluster_c", "cluster_b", "cluster_a", "cluster_d",
  ])
}

///|
test "build_cluster_graph_order honors explicit parent hints before cluster_order tie-breaks" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(root.subgraph(name="cluster_a"))
  ignore(root.subgraph(name="cluster_b"))
  ignore(root.subgraph(name="cluster_c"))

  let cluster_parents_hint : Map[String, String?] = Map::new()
  cluster_parents_hint["cluster_b"] = Some("cluster_a")
  cluster_parents_hint["cluster_c"] = Some("cluster_b")

  let ordered = build_cluster_graph_order(
    root,
    ["cluster_c", "cluster_b", "cluster_a"],
    cluster_parents_hint,
  )

  assert_eq(ordered.cluster_names, ["cluster_a", "cluster_b", "cluster_c"])
}
