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
test "collect_top_clusters keeps only top-level clusters and excludes the cluster source itself" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let outer = root.subgraph(name="cluster_outer")
  let peer = root.subgraph(name="cluster_peer")
  let inner = outer.subgraph(name="cluster_inner")
  ignore(outer.node("a"))
  ignore(peer.node("b"))
  ignore(inner.node("c"))

  let root_collected = collect_top_clusters(root)
  let root_top : Map[String, Bool] = Map::new()
  for name in root_collected.top_clusters {
    root_top[name] = true
  }
  assert_eq(root_top.length(), 2)
  assert_eq(root_top.get("cluster_outer"), Some(true))
  assert_eq(root_top.get("cluster_peer"), Some(true))
  assert_eq(root_top.get("cluster_inner"), None)

  let cluster_collected = collect_top_clusters(outer)
  assert_eq(cluster_collected.top_clusters.length(), 0)
  assert_eq(cluster_collected.cluster_graphs.length(), 2)
  match cluster_collected.cluster_graphs.get("cluster_outer") {
    Some(_) => ()
    None => fail("missing cluster_outer graph")
  }
  match cluster_collected.cluster_graphs.get("cluster_inner") {
    Some(_) => ()
    None => fail("missing cluster_inner graph")
  }
}

///|
test "collect_cluster_members omits empty clusters and node index ignores missing member maps" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let empty = root.subgraph(name="cluster_empty")
  let full = root.subgraph(name="cluster_full")
  ignore(empty)
  ignore(full.node("a"))

  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(root)
  let members = collect_cluster_members(cluster_maps.cluster_graphs)

  assert_eq(members.get("cluster_empty"), None)
  let full_members = match members.get("cluster_full") {
    Some(value) => value
    None => fail("missing cluster_full members")
  }
  assert_eq(full_members.length(), 1)
  assert_eq(full_members.get("a"), Some(true))

  let node_cluster = build_node_cluster_index(
    ["cluster_missing", "cluster_full"],
    members,
  )
  assert_eq(node_cluster.length(), 1)
  assert_eq(node_cluster.get("a"), Some("cluster_full"))
  assert_eq(node_cluster.get("b"), None)
}

///|
test "compute_local_cluster_ranks_and_leaders filters external edges and falls back to the first node" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let internal = graph.edge(a, b)
  let external = graph.edge(b, c)

  let top_clusters = ["cluster0"]
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster0_members : Map[String, Bool] = Map::new()
  cluster0_members["a"] = true
  cluster0_members["b"] = true
  let cluster_members : Map[String, Map[String, Bool]] = Map::new()
  cluster_members["cluster0"] = cluster0_members

  let seen_graph_is_root : Array[Bool] = []
  let seen_cluster_nodes : Array[String] = []
  let seen_cluster_edges : Array[String] = []
  let result = compute_local_cluster_ranks_and_leaders(
    graph,
    [b, a, c],
    [internal, external],
    top_clusters,
    cluster_graphs,
    cluster_members,
    (cluster_graph, cluster_nodes, cluster_edges) => {
      seen_graph_is_root.push(cluster_graph.is_root())
      let cluster_node_names : Array[String] = []
      for node in cluster_nodes {
        cluster_node_names.push(node.name())
      }
      seen_cluster_nodes.push(cluster_node_names.join(","))
      let cluster_edge_names : Array[String] = []
      for edge in cluster_edges {
        cluster_edge_names.push("\{edge.tail().name()}->\{edge.head().name()}")
      }
      seen_cluster_edges.push(cluster_edge_names.join(","))

      let cluster_ranks : Map[String, Int] = Map::new()
      cluster_ranks["a"] = 2
      cluster_ranks["b"] = 4
      cluster_ranks
    },
  )

  assert_eq(seen_graph_is_root, [true])
  assert_eq(seen_cluster_nodes, ["b,a"])
  assert_eq(seen_cluster_edges, ["a->b"])
  assert_eq(result.local_ranks.get("a"), Some(2))
  assert_eq(result.local_ranks.get("b"), Some(4))
  assert_eq(result.cluster_leaders.get("cluster0"), Some("b"))
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
test "solve_clustered_leader_ranks forwards only clusterless constrained direct edges to the orient step" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let direct_ab_1 = graph.edge(a, b)
  direct_ab_1.set_attr("minlen", "1")
  direct_ab_1.set_attr("weight", "2")
  let direct_ab_2 = graph.edge(a, b)
  direct_ab_2.set_attr("minlen", "3")
  direct_ab_2.set_attr("weight", "5")
  let self_edge = graph.edge(a, a)
  self_edge.set_attr("minlen", "4")
  let unconstrained = graph.edge(b, c)
  unconstrained.set_attr("constraint", "false")

  let node_cluster : Map[String, String] = Map::new()
  let cluster_leaders : Map[String, String] = Map::new()
  let local_ranks : Map[String, Int] = Map::new()
  let seen_tail : Array[String] = []
  let seen_head : Array[String] = []
  let seen_active : Array[Bool] = []
  let leader_ranks = solve_clustered_leader_ranks(
    [a, b, c],
    [direct_ab_1, direct_ab_2, self_edge, unconstrained],
    node_cluster,
    cluster_leaders,
    local_ranks,
    false,
    10,
    (node_names, edge_tail, edge_head, edge_is_active) => {
      ignore(node_names)
      for name in edge_tail {
        seen_tail.push(name)
      }
      for name in edge_head {
        seen_head.push(name)
      }
      for active in edge_is_active {
        seen_active.push(active)
      }
      identity_orient_edges_for_names(
        node_names, edge_tail, edge_head, edge_is_active,
      )
    },
  )

  assert_eq(seen_tail, ["a", "a"])
  assert_eq(seen_head, ["b", "b"])
  assert_eq(seen_active, [true, true])
  assert_eq(leader_ranks.get("a"), Some(0))
  assert_eq(leader_ranks.get("b"), Some(3))
  assert_eq(leader_ranks.get("c"), Some(0))
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
