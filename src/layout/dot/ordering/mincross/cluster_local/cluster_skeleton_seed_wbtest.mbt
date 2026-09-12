///|
test "child skeleton seeds precede direct nodes through anonymous scopes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_x")
  ignore(cluster.node("x"))
  let scope = cluster.subgraph()
  let child = scope.subgraph(name="cluster_y")
  ignore(child.node("y"))
  let order = cluster_class2_seed_order(cluster, { "x": 0, "y": 1 })
  assert_true(order.get("y") == Some(0))
  assert_true(order.get("x") == Some(1))
  let groups = build_local_rank_groups(
    { 0: ["x", "y"] },
    { "x": true, "y": true },
    order,
    {},
  )
  assert_true(groups.get(0) == Some(["y", "x"]))
}

///|
test "cluster class2 real-node seeds ignore enclosing root DFS order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_core")
  ignore(cluster.node("input"))
  ignore(cluster.node("reachable"))
  ignore(cluster.node("independent"))
  let order = cluster_class2_seed_order(cluster, {
    "independent": 0,
    "input": 1,
    "reachable": 2,
  })
  @test.assert_eq(order.get("input"), Some(0))
  @test.assert_eq(order.get("reachable"), Some(1))
  @test.assert_eq(order.get("independent"), Some(2))
}
