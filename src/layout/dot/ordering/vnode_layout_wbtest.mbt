///|
fn build_edge_vnodes_for_test(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rankdir : @rankdir.RankDir,
) -> @routing.EdgeVnodeInfo {
  let nodes = graph.nodes()
  let edges = graph.edges()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  @clustering.collect_edge_cluster_keys(graph, edge_cluster_keys)
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(graph)
  build_edge_vnodes(
    nodes,
    edges,
    [],
    [],
    Map::new(),
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_maps.cluster_parents,
  )
}

///|
fn edge_vnode_chain_for_test(
  vnode_info : @routing.EdgeVnodeInfo,
  edge : @cgraph.Edge,
) -> Array[String] raise {
  match vnode_info.edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
    Some(value) => value
    None => fail("missing vnode chain for edge")
  }
}

///|
fn vnode_size_for_test(
  vnode_info : @routing.EdgeVnodeInfo,
  name : String,
) -> @node_primitives.NodeSize raise {
  match vnode_info.vnode_sizes.get(name) {
    Some(value) => value
    None => fail("missing vnode size for \{name}")
  }
}

///|
test "build_edge_vnodes places the LR label vnode at midpoint rank and swaps label dimensions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 4

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::LR,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  assert_eq(chain.length(), 3)
  assert_eq(vnode_info.vnode_ranks.get(chain[0]), Some(1))
  assert_eq(vnode_info.vnode_ranks.get(chain[1]), Some(2))
  assert_eq(vnode_info.vnode_ranks.get(chain[2]), Some(3))

  let plain = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(plain.left_pt, 11.0)
  assert_eq(plain.right_pt, 11.0)
  assert_eq(plain.height_pt, @node_primitives.VNODE_HEIGHT_PT)

  let label = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(label.left_pt, 20.0)
  assert_eq(label.right_pt, metrics.height)
  assert_eq(label.height_pt, metrics.width)
}

///|
test "build_edge_vnodes places the TB label vnode at midpoint rank with unflipped dimensions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "Very Long Edge Label")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 5

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }

  assert_eq(chain.length(), 4)
  assert_eq(vnode_info.vnode_ranks.get(chain[0]), Some(1))
  assert_eq(vnode_info.vnode_ranks.get(chain[1]), Some(2))
  assert_eq(vnode_info.vnode_ranks.get(chain[2]), Some(3))
  assert_eq(vnode_info.vnode_ranks.get(chain[3]), Some(4))

  let plain = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(plain.left_pt, 11.0)
  assert_eq(plain.right_pt, 11.0)
  assert_eq(plain.height_pt, @node_primitives.VNODE_HEIGHT_PT)

  let label = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(label.left_pt, 20.0)
  assert_eq(label.right_pt, metrics.width)
  assert_eq(label.height_pt, metrics.height)
}

///|
test "build_edge_vnodes widens shared chains for parallel unlabeled edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge1 = graph.edge(a, b)
  let edge2 = graph.edge(a, b)
  ignore(edge2)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge1)

  assert_eq(chain.length(), 2)
  let first = vnode_size_for_test(vnode_info, chain[0])
  let second = vnode_size_for_test(vnode_info, chain[1])
  assert_eq(first.left_pt, 21.0)
  assert_eq(first.right_pt, 21.0)
  assert_eq(second.left_pt, 21.0)
  assert_eq(second.right_pt, 21.0)
}

///|
test "build_edge_vnodes reuses the same chain for reverse unlabeled duplicates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let reverse = graph.edge(b, a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let forward_chain = edge_vnode_chain_for_test(vnode_info, forward)
  let reverse_chain = edge_vnode_chain_for_test(vnode_info, reverse)

  assert_eq(reverse_chain, forward_chain)
  let first = vnode_size_for_test(vnode_info, forward_chain[0])
  assert_eq(first.left_pt, 21.0)
  assert_eq(first.right_pt, 21.0)
}

///|
test "build_edge_vnodes keeps cluster-local parallel chains at plain virtual width" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  let edge1 = graph.edge(a, b)
  let edge2 = graph.edge(a, b)
  ignore(edge2)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge1)

  assert_eq(chain.length(), 2)
  let first = vnode_size_for_test(vnode_info, chain[0])
  assert_eq(first.left_pt, 1.0)
  assert_eq(first.right_pt, 1.0)
  for name in chain {
    assert_eq(vnode_info.vnode_clusters.get(name), Some("cluster_0"))
  }
}

///|
test "build_edge_vnodes leaves cross-root-cluster chains unowned and at standard width" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let left = graph.subgraph(name="cluster_left")
  let right = graph.subgraph(name="cluster_right")
  let a = left.node("a")
  let b = right.node("b")
  let edge = graph.edge(a, b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3

  let vnode_info = build_edge_vnodes_for_test(
    graph,
    ranks,
    20.0,
    @rankdir.RankDir::TB,
  )
  let chain = edge_vnode_chain_for_test(vnode_info, edge)
  let first = vnode_size_for_test(vnode_info, chain[0])

  assert_eq(first.left_pt, 11.0)
  assert_eq(first.right_pt, 11.0)
  for name in chain {
    assert_eq(vnode_info.vnode_clusters.get(name), Some(""))
  }
}
