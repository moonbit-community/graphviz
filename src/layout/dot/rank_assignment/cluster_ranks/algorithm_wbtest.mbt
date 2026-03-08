///|
test "collect_rank_extremes descends nested subgraphs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(graph.node("a"))
  ignore(graph.node("b"))
  ignore(graph.node("c"))
  let nested = graph.subgraph(name="nested")
  let source = nested.subgraph(name="source")
  source.set_attr("rank", "source")
  ignore(source.node("a"))
  let sink = graph.subgraph(name="sink")
  sink.set_attr("rank", "sink")
  ignore(sink.node("b"))

  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(graph, min_nodes, max_nodes)

  assert_eq(min_nodes.get("a"), Some(true))
  assert_eq(max_nodes.get("b"), Some(true))
  assert_eq(min_nodes.get("c"), None)
  assert_eq(max_nodes.get("c"), None)
}

///|
test "cluster rank projection combines leader and local ranks then normalizes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")

  let cluster0_members : Map[String, Bool] = Map::new()
  cluster0_members["a"] = true
  cluster0_members["b"] = true
  let cluster_members : Map[String, Map[String, Bool]] = Map::new()
  cluster_members["cluster0"] = cluster0_members

  let node_cluster = build_node_cluster_index(["cluster0"], cluster_members)
  let cluster_leaders : Map[String, String] = Map::new()
  cluster_leaders["cluster0"] = "leader0"
  let local_ranks : Map[String, Int] = Map::new()
  local_ranks["a"] = 2
  local_ranks["b"] = 4
  let leader_ranks : Map[String, Int] = Map::new()
  leader_ranks["leader0"] = 5
  leader_ranks["c"] = 1

  let ranks = project_clustered_node_ranks(
    [a, b, c],
    node_cluster,
    cluster_leaders,
    local_ranks,
    leader_ranks,
  )

  assert_eq(ranks.get("a"), Some(6))
  assert_eq(ranks.get("b"), Some(8))
  assert_eq(ranks.get("c"), Some(0))
}

///|
test "apply_clustered_rank_postprocessing collapses rank sets and enforces extrema" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")

  let same = graph.subgraph(name="same")
  same.set_attr("rank", "same")
  ignore(same.node("a"))
  ignore(same.node("b"))

  let source = graph.subgraph(name="source")
  source.set_attr("rank", "source")
  ignore(source.node("c"))

  let sink = graph.subgraph(name="sink")
  sink.set_attr("rank", "sink")
  ignore(sink.node("d"))

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 4
  ranks["b"] = 7
  ranks["c"] = 3
  ranks["d"] = 1

  let result = apply_clustered_rank_postprocessing(graph, [a, b, c, d], ranks)

  assert_eq(result.get("a"), Some(4))
  assert_eq(result.get("b"), Some(4))
  assert_eq(result.get("c"), Some(0))
  assert_eq(result.get("d"), Some(4))
}

///|
fn identity_orient_edges_for_names(
  node_names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_is_active : Array[Bool],
) -> (Array[String], Array[String], Array[Bool]) {
  ignore(node_names)
  ignore(edge_is_active)
  let reversed : Array[Bool] = []
  for _ in 0..<edge_tail.length() {
    reversed.push(false)
  }
  (edge_tail.copy(), edge_head.copy(), reversed)
}

///|
test "solve_clustered_leader_ranks converts positive cross-cluster offset into head separation" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a0 = graph.node("a0")
  let b0 = graph.node("b0")
  let edge = graph.edge(a0, b0)
  edge.set_attr("minlen", "1")
  edge.set_attr("weight", "2")

  let node_cluster : Map[String, String] = Map::new()
  node_cluster["a0"] = "cluster_a"
  node_cluster["b0"] = "cluster_b"

  let cluster_leaders : Map[String, String] = Map::new()
  cluster_leaders["cluster_a"] = "a0"
  cluster_leaders["cluster_b"] = "b0"

  let local_ranks : Map[String, Int] = Map::new()
  local_ranks["a0"] = 0
  local_ranks["b0"] = 0

  let leader_ranks = solve_clustered_leader_ranks(
    [a0, b0],
    [edge],
    node_cluster,
    cluster_leaders,
    local_ranks,
    false,
    10,
    identity_orient_edges_for_names,
  )

  assert_eq(leader_ranks.get("a0"), Some(0))
  assert_eq(leader_ranks.get("b0"), Some(1))
}

///|
test "solve_clustered_leader_ranks converts negative cross-cluster offset into tail separation" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a0 = graph.node("a0")
  let b0 = graph.node("b0")
  let b2 = graph.node("b2")
  let edge = graph.edge(a0, b2)
  edge.set_attr("minlen", "1")
  edge.set_attr("weight", "2")

  let node_cluster : Map[String, String] = Map::new()
  node_cluster["a0"] = "cluster_a"
  node_cluster["b0"] = "cluster_b"
  node_cluster["b2"] = "cluster_b"

  let cluster_leaders : Map[String, String] = Map::new()
  cluster_leaders["cluster_a"] = "a0"
  cluster_leaders["cluster_b"] = "b0"

  let local_ranks : Map[String, Int] = Map::new()
  local_ranks["a0"] = 0
  local_ranks["b0"] = 0
  local_ranks["b2"] = 2

  let leader_ranks = solve_clustered_leader_ranks(
    [a0, b0, b2],
    [edge],
    node_cluster,
    cluster_leaders,
    local_ranks,
    false,
    10,
    identity_orient_edges_for_names,
  )

  assert_eq(leader_ranks.get("a0"), Some(1))
  assert_eq(leader_ranks.get("b0"), Some(0))
}
