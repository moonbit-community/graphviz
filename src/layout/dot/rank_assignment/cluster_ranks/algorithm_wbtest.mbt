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

///|
fn base_recursive_ranks(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
) -> Map[String, Int] {
  ignore(back_weight_scale)
  let directions = @solver.acyclic_edge_directions_with_order(
    graph, nodes, edges,
  )
  @solver.compute_ranks_directed_base(
    graph,
    nodes,
    edges,
    has_edge_labels,
    directions.tail,
    directions.head,
  )
}

///|
test "compute_clustered_ranks projects local cluster ranks into the outer solve" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster0")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  ignore(cluster.node("a"))
  ignore(cluster.node("b"))
  let ab = graph.edge(a, b)
  ab.set_attr("minlen", "1")
  let ac = graph.edge(a, c)
  ac.set_attr("minlen", "1")

  let ranks = compute_clustered_ranks(
    graph,
    [a, b, c],
    [ab, ac],
    false,
    10,
    base_recursive_ranks,
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
  assert_eq(ranks.get("c"), Some(1))
}
