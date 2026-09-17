///|
test "ordinary vnodes retain both original endpoint clusters" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let origins = original_vnode_origin_clusters(
    [edge],
    Map([(@edge_identity.edge_vnode_key(edge), ["v1", "v2"])]),
    { "a": "cluster_inner", "b": "cluster_outer" },
  )
  @test.assert_eq(origins.get("v1"), Some(("cluster_inner", "cluster_outer")))
  @test.assert_eq(origins.get("v2"), Some(("cluster_inner", "cluster_outer")))
}
