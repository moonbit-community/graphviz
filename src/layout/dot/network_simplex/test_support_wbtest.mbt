///|
fn collect_node_ranks(graph : NsGraph) -> Array[Int] {
  let ranks : Array[Int] = []
  for i in 0..<graph.nodes.length() {
    ranks.push(node_rank(graph, i))
  }
  ranks
}

///|
fn feasible_tree_edges_for_test(graph : NsGraph) -> Array[Int] raise {
  if !build_feasible_tree(graph) {
    fail("expected feasible tree")
  }
  graph.tree_edges
}

///|
fn pre_balance_ranks_for_test(graph : NsGraph) -> Array[Int] raise {
  if !network_simplex_pre_balance(graph, 0x7fffffff) {
    fail("expected network_simplex_pre_balance to succeed")
  }
  collect_node_ranks(graph)
}

///|
struct ExactRankNodeSpec {
  name : String
  kind : NodeKind
  rank : Int
}

///|
struct ExactRankEdgeSpec {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
  in_pos : Int
}

///|
fn build_exact_rank_fixture_graph(
  node_specs : Array[ExactRankNodeSpec],
  edge_specs : Array[ExactRankEdgeSpec],
) -> NsGraph {
  let graph = new_graph()
  for spec in node_specs {
    let node = add_node(graph, spec.name, kind=spec.kind)
    set_node_rank(graph, node, spec.rank)
  }
  let in_positions : Array[Int] = []
  for spec in edge_specs {
    ignore(add_edge(graph, spec.tail, spec.head, spec.minlen, spec.weight))
    in_positions.push(spec.in_pos)
  }
  for i in 0..<graph.nodes.length() {
    graph.nodes[i].in_edges.sort_by((a, b) => {
      let a_pos = in_positions[a]
      let b_pos = in_positions[b]
      if a_pos < b_pos {
        -1
      } else if a_pos > b_pos {
        1
      } else if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    })
  }
  graph
}

///|
struct CapturedRankEdgeSpec {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
fn build_captured_rank_fixture_graph(
  node_specs : Array[ExactRankNodeSpec],
  edge_specs : Array[CapturedRankEdgeSpec],
) -> NsGraph {
  let graph = new_graph()
  for spec in node_specs {
    let node = add_node(graph, spec.name, kind=spec.kind)
    set_node_rank(graph, node, spec.rank)
  }
  for spec in edge_specs {
    ignore(add_edge(graph, spec.tail, spec.head, spec.minlen, spec.weight))
  }
  graph
}

///|
fn build_lr_edge_labels_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let s2 = add_node(graph, "", kind=NodeKind::Slack)
  let s3 = add_node(graph, "", kind=NodeKind::Slack)
  let a = add_node(graph, "a")
  let v0 = add_node(graph, "", kind=NodeKind::Virtual)
  let c = add_node(graph, "c")
  let b = add_node(graph, "b")
  let v1 = add_node(graph, "", kind=NodeKind::Virtual)
  let d = add_node(graph, "d")
  set_node_rank(graph, s0, 71)
  set_node_rank(graph, s1, 71)
  set_node_rank(graph, s2, -1)
  set_node_rank(graph, s3, -1)
  set_node_rank(graph, a, 0)
  set_node_rank(graph, v0, 0)
  set_node_rank(graph, c, 0)
  set_node_rank(graph, b, 72)
  set_node_rank(graph, v1, 98)
  set_node_rank(graph, d, 72)
  ignore(add_edge(graph, s0, v1, 1, 2))
  ignore(add_edge(graph, s0, d, 1, 2))
  ignore(add_edge(graph, s1, b, 1, 2))
  ignore(add_edge(graph, s1, v1, 1, 2))
  ignore(add_edge(graph, s2, v0, 1, 2))
  ignore(add_edge(graph, s2, c, 1, 2))
  ignore(add_edge(graph, s3, a, 1, 2))
  ignore(add_edge(graph, s3, v0, 1, 2))
  ignore(add_edge(graph, a, b, 72, 0))
  ignore(add_edge(graph, v0, v1, 98, 0))
  ignore(add_edge(graph, c, d, 72, 0))
  graph
}

///|
fn build_lr_xlabels_tb_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let s2 = add_node(graph, "", kind=NodeKind::Slack)
  let s3 = add_node(graph, "", kind=NodeKind::Slack)
  let s4 = add_node(graph, "", kind=NodeKind::Slack)
  let s5 = add_node(graph, "", kind=NodeKind::Slack)
  let b = add_node(graph, "b")
  let a = add_node(graph, "a")
  let c = add_node(graph, "c")
  set_node_rank(graph, s0, 0)
  set_node_rank(graph, s1, 0)
  set_node_rank(graph, s2, 0)
  set_node_rank(graph, s3, 0)
  set_node_rank(graph, s4, -1)
  set_node_rank(graph, s5, -1)
  set_node_rank(graph, b, 72)
  set_node_rank(graph, a, 0)
  set_node_rank(graph, c, 0)
  ignore(add_edge(graph, s1, s3, 8, 0))
  ignore(add_edge(graph, s2, s0, 8, 0))
  ignore(add_edge(graph, s3, s2, 81, 128))
  ignore(add_edge(graph, s3, a, 35, 0))
  ignore(add_edge(graph, s4, a, 1, 1))
  ignore(add_edge(graph, s4, c, 1, 1))
  ignore(add_edge(graph, s5, b, 1, 1))
  ignore(add_edge(graph, s5, c, 1, 1))
  ignore(add_edge(graph, b, s2, 35, 0))
  ignore(add_edge(graph, a, b, 72, 0))
  graph
}

///|
fn build_lr_edge_vnode_spacing_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "", kind: NodeKind::Slack, rank: 49 },
      { name: "", kind: NodeKind::Slack, rank: 49 },
      { name: "", kind: NodeKind::Slack, rank: 109 },
      { name: "", kind: NodeKind::Slack, rank: 109 },
      { name: "", kind: NodeKind::Slack, rank: 49 },
      { name: "", kind: NodeKind::Slack, rank: 49 },
      { name: "", kind: NodeKind::Slack, rank: 24 },
      { name: "", kind: NodeKind::Slack, rank: 24 },
      { name: "", kind: NodeKind::Slack, rank: 32 },
      { name: "", kind: NodeKind::Slack, rank: 32 },
      { name: "", kind: NodeKind::Slack, rank: 24 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "a", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 0 },
      { name: "c", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 0 },
      { name: "e", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 0 },
      { name: "g", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 25 },
      { name: "", kind: NodeKind::Virtual, rank: 55 },
      { name: "", kind: NodeKind::Virtual, rank: 33 },
      { name: "", kind: NodeKind::Virtual, rank: 55 },
      { name: "", kind: NodeKind::Virtual, rank: 25 },
      { name: "h", kind: NodeKind::Normal, rank: 72 },
      { name: "", kind: NodeKind::Virtual, rank: 50 },
      { name: "f", kind: NodeKind::Normal, rank: 110 },
      { name: "", kind: NodeKind::Virtual, rank: 175 },
      { name: "d", kind: NodeKind::Normal, rank: 110 },
      { name: "", kind: NodeKind::Virtual, rank: 50 },
      { name: "b", kind: NodeKind::Normal, rank: 72 },
    ],
    [
      { tail: 0, head: 36, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 0, head: 35, minlen: 1, weight: 2, in_pos: 2 },
      { tail: 1, head: 35, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 1, head: 34, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 2, head: 34, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 2, head: 33, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 3, head: 33, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 3, head: 32, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 4, head: 32, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 4, head: 31, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 5, head: 31, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 5, head: 30, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 6, head: 29, minlen: 1, weight: 1, in_pos: 2 },
      { tail: 6, head: 30, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 7, head: 28, minlen: 1, weight: 4, in_pos: 2 },
      { tail: 7, head: 29, minlen: 1, weight: 4, in_pos: 1 },
      { tail: 8, head: 27, minlen: 1, weight: 4, in_pos: 2 },
      { tail: 8, head: 28, minlen: 1, weight: 4, in_pos: 1 },
      { tail: 9, head: 26, minlen: 1, weight: 4, in_pos: 2 },
      { tail: 9, head: 27, minlen: 1, weight: 4, in_pos: 1 },
      { tail: 10, head: 25, minlen: 1, weight: 4, in_pos: 2 },
      { tail: 10, head: 26, minlen: 1, weight: 4, in_pos: 1 },
      { tail: 11, head: 23, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 11, head: 24, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 12, head: 22, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 12, head: 23, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 13, head: 21, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 13, head: 22, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 14, head: 20, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 14, head: 21, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 15, head: 19, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 15, head: 20, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 16, head: 18, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 16, head: 25, minlen: 1, weight: 1, in_pos: 1 },
      { tail: 17, head: 18, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 17, head: 19, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 18, head: 36, minlen: 72, weight: 0, in_pos: 0 },
      { tail: 19, head: 25, minlen: 25, weight: 0, in_pos: 0 },
      { tail: 20, head: 26, minlen: 55, weight: 0, in_pos: 0 },
      { tail: 21, head: 27, minlen: 33, weight: 0, in_pos: 0 },
      { tail: 22, head: 28, minlen: 55, weight: 0, in_pos: 0 },
      { tail: 23, head: 29, minlen: 25, weight: 0, in_pos: 0 },
      { tail: 24, head: 30, minlen: 72, weight: 0, in_pos: 0 },
      { tail: 25, head: 35, minlen: 25, weight: 0, in_pos: 0 },
      { tail: 26, head: 34, minlen: 55, weight: 0, in_pos: 0 },
      { tail: 27, head: 33, minlen: 142, weight: 0, in_pos: 0 },
      { tail: 28, head: 32, minlen: 55, weight: 0, in_pos: 0 },
      { tail: 29, head: 31, minlen: 25, weight: 0, in_pos: 0 },
    ],
  )
}
