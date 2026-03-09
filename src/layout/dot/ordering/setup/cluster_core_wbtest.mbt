///|
test "build_cluster_core_metadata_for_ordering seeds orders and collects cluster metadata" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let outer = root.subgraph(name="cluster_outer")
  let plain = root.subgraph(name="plain")
  let other = plain.subgraph(name="cluster_other")
  let inner = outer.subgraph(name="cluster_inner")

  let a = outer.node("a")
  let b = inner.node("b")
  let c = other.node("c")
  let d = root.node("d")
  ignore(a)
  ignore(b)
  ignore(c)
  ignore(d)

  let nodes = [a, b, c, d]
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "d"]
  groups[1] = ["b", "c"]
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1
  ranks["c"] = 1
  let node_order : Map[String, Int] = Map::new()

  let metadata = build_cluster_core_metadata_for_ordering(
    root,
    nodes,
    groups,
    ranks,
    node_order,
    false,
    true,
  )

  assert_true(metadata.has_clusters)
  assert_eq(metadata.cluster_keys.get("a"), Some("cluster_outer"))
  assert_eq(metadata.cluster_keys.get("b"), Some("cluster_outer"))
  assert_eq(metadata.cluster_keys.get("c"), Some("cluster_other"))
  assert_eq(metadata.cluster_keys.get("d"), Some(""))
  assert_eq(metadata.intercluster_keys.get("a"), Some("cluster_outer"))
  assert_eq(metadata.intercluster_keys.get("b"), Some("cluster_inner"))
  assert_eq(metadata.intercluster_keys.get("c"), Some("cluster_other"))
  assert_eq(metadata.intercluster_keys.get("d"), Some(""))

  assert_eq(metadata.cluster_skeleton.get("a"), Some(true))
  assert_eq(metadata.cluster_skeleton.get("b"), Some(true))
  assert_eq(metadata.cluster_skeleton.get("c"), Some(true))
  assert_true(metadata.cluster_skeleton.get("d") is None)

  assert_eq(metadata.cluster_min_rank.get("cluster_outer"), Some(0))
  assert_eq(metadata.cluster_max_rank.get("cluster_outer"), Some(1))
  assert_eq(metadata.cluster_min_rank.get("cluster_other"), Some(1))
  assert_eq(metadata.cluster_max_rank.get("cluster_other"), Some(1))

  assert_eq(metadata.cluster_order, ["cluster_outer", "cluster_other"])
  assert_eq(metadata.cluster_parents.get("cluster_outer"), Some(None))
  assert_eq(metadata.cluster_parents.get("cluster_other"), Some(None))
  assert_eq(metadata.cluster_parents.get("cluster_inner"), Some(Some("cluster_outer")))

  assert_eq(node_order.get("a"), Some(0))
  assert_eq(node_order.get("b"), Some(1))
  assert_eq(node_order.get("c"), Some(7))
  assert_true(node_order.get("d") is None)
}

///|
test "build_cluster_core_metadata_for_ordering respects graphviz_flip without cluster order base" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  ignore(a)
  ignore(b)

  let nodes = [a, b]
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  let node_order : Map[String, Int] = Map::new()

  let metadata = build_cluster_core_metadata_for_ordering(
    root,
    nodes,
    groups,
    ranks,
    node_order,
    true,
    false,
  )

  assert_true(metadata.has_clusters)
  assert_eq(node_order.get("a"), Some(1))
  assert_eq(node_order.get("b"), Some(0))
  assert_eq(metadata.cluster_skeleton.get("a"), Some(true))
  assert_true(metadata.cluster_skeleton.get("b") is None)
}
