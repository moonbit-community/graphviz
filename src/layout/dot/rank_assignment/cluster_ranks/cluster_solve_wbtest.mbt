// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
fn identity_cluster_solver_orient_edges(
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
      identity_cluster_solver_orient_edges(
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
    identity_cluster_solver_orient_edges,
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
    identity_cluster_solver_orient_edges,
  )

  assert_eq(leader_ranks.get("a0"), Some(1))
  assert_eq(leader_ranks.get("b0"), Some(0))
}
