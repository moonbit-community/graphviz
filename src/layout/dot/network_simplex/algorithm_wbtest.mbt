///|
fn build_init_rank_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, c, 1, 1))
  ignore(add_edge(graph, b, c, 3, 1))
  graph
}

///|
fn build_feasible_tree_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, b, 2, 1))
  ignore(add_edge(graph, b, c, 1, 1))
  ignore(add_edge(graph, a, c, 4, 1))
  graph
}

///|
fn build_tb_balance_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, b, 1, 1))
  ignore(add_edge(graph, b, c, 1, 1))
  ignore(add_edge(graph, a, c, 4, 1))
  graph
}

///|
fn collect_node_ranks(graph : NsGraph) -> Array[Int] {
  let ranks : Array[Int] = []
  for i in 0..<graph.nodes.length() {
    ranks.push(node_rank(graph, i))
  }
  ranks
}

///|
test "init_rank uses the maximum incoming minlen constraint" {
  let graph = build_init_rank_graph()
  ignore(init_graph(graph))
  init_rank(graph)

  assert_eq(collect_node_ranks(graph), [0, 0, 3])
}

///|
test "normalize_ranks_for_test shifts the minimum rank to zero" {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  set_node_rank(graph, a, -3)
  set_node_rank(graph, b, -1)
  set_node_rank(graph, c, 2)

  let max_rank = normalize_ranks_for_test(graph)

  assert_eq(max_rank, 5)
  assert_eq(collect_node_ranks(graph), [0, 2, 5])
}

///|
test "build_feasible_tree selects a tight spanning tree" {
  let graph = build_feasible_tree_graph()

  guard build_feasible_tree(graph) else {
    fail("expected feasible tree to exist")
  }
  assert_eq(graph.tree_edges.length(), graph.nodes.length() - 1)
  for edge_idx in graph.tree_edges {
    assert_eq(edge_slack(graph, edge_idx), 0)
  }
  for node_idx in 1..<graph.nodes.length() {
    guard graph.nodes[node_idx].par_edge != NONE_EDGE else {
      fail("expected node \{node_idx} to receive a parent edge")
    }
  }
}

///|
test "network_simplex TB balance moves a node to the sparsest feasible rank" {
  let graph = build_tb_balance_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::TB)

  assert_eq(collect_node_ranks(graph), [0, 2, 4])
}

///|
fn build_lr_fanout_graph() -> NsGraph {
  let graph = new_graph()
  let slack = add_node(graph, "slack", kind=NodeKind::Slack)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  ignore(add_edge(graph, slack, a, 1, 2))
  ignore(add_edge(graph, slack, b, 1, 2))
  graph
}

///|
fn build_lr_port_label_graph() -> NsGraph {
  let graph = new_graph()
  let s2 = add_node(graph, "s2", kind=NodeKind::Slack)
  let s1 = add_node(graph, "s1", kind=NodeKind::Slack)
  let s0 = add_node(graph, "s0", kind=NodeKind::Slack)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  let d = add_node(graph, "d")
  let e = add_node(graph, "e")
  let f = add_node(graph, "f")
  ignore(add_edge(graph, s2, e, 1, 2))
  ignore(add_edge(graph, s2, f, 1, 2))
  ignore(add_edge(graph, s1, c, 1, 2))
  ignore(add_edge(graph, s1, d, 1, 2))
  ignore(add_edge(graph, s0, a, 1, 2))
  ignore(add_edge(graph, s0, b, 1, 2))
  ignore(add_edge(graph, a, c, 72, 0))
  ignore(add_edge(graph, b, d, 72, 0))
  ignore(add_edge(graph, c, e, 72, 0))
  ignore(add_edge(graph, d, f, 72, 0))
  graph
}

///|
test "normalize_ranks_for_test ignores auxiliary nodes when choosing the origin" {
  let graph = new_graph()
  let slack = add_node(graph, "slack", kind=NodeKind::Slack)
  let vnode = add_node(graph, "virtual", kind=NodeKind::Virtual)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  set_node_rank(graph, slack, -50)
  set_node_rank(graph, vnode, -30)
  set_node_rank(graph, a, 10)
  set_node_rank(graph, b, 14)

  let max_rank = normalize_ranks_for_test(graph)

  assert_eq(max_rank, 4)
  assert_eq(collect_node_ranks(graph), [-60, -40, 0, 4])
}

///|
test "sort_nodes_by_rank is stable for equal-rank nodes" {
  let graph = new_graph()
  let n0 = add_node(graph, "n0")
  let n1 = add_node(graph, "n1")
  let n2 = add_node(graph, "n2")
  let n3 = add_node(graph, "n3")
  let n4 = add_node(graph, "n4")
  set_node_rank(graph, n0, 2)
  set_node_rank(graph, n1, 1)
  set_node_rank(graph, n2, 2)
  set_node_rank(graph, n3, 1)
  set_node_rank(graph, n4, 2)
  let nodes = [n0, n1, n2, n3, n4]

  sort_nodes_by_rank(graph, nodes)

  assert_eq(nodes, [n1, n3, n0, n2, n4])
}

///|
test "network_simplex LR keeps symmetric fanout nodes aligned" {
  let graph = build_lr_fanout_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  let ranks = collect_node_ranks(graph)

  assert_eq(ranks.length(), 3)
  assert_eq(ranks[1], ranks[2])
  assert_eq(ranks[1] - ranks[0], 1)
}

///|
test "network_simplex LR preserves layered port-label ladder spacing" {
  let graph = build_lr_port_label_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  let ranks = collect_node_ranks(graph)

  assert_eq(ranks.length(), 9)
  assert_eq(ranks[3], ranks[4])
  assert_eq(ranks[5], ranks[6])
  assert_eq(ranks[7], ranks[8])
  assert_eq(ranks[5] - ranks[3], 72)
  assert_eq(ranks[7] - ranks[5], 72)
  assert_eq(ranks[3] - ranks[2], 1)
  assert_eq(ranks[5] - ranks[1], 1)
  assert_eq(ranks[7] - ranks[0], 1)
}

///|
struct LrChainCase {
  graph : NsGraph
  ab : Int
  bc : Int
}

///|
fn build_lr_chain_case(ac_minlen : Int) -> LrChainCase {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  let ab = add_edge(graph, a, b, 1, 1)
  let bc = add_edge(graph, b, c, 1, 1)
  ignore(add_edge(graph, a, c, ac_minlen, 1))
  { graph, ab, bc }
}

///|
struct LrOddSlackDiamondCase {
  graph : NsGraph
  ac : Int
  cd : Int
}

///|
fn build_lr_odd_slack_diamond_case() -> LrOddSlackDiamondCase {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  let d = add_node(graph, "d")
  ignore(add_edge(graph, a, b, 1, 1))
  let ac = add_edge(graph, a, c, 1, 1)
  ignore(add_edge(graph, b, d, 4, 1))
  let cd = add_edge(graph, c, d, 1, 1)
  { graph, ac, cd }
}

///|
struct LrFanInCase {
  graph : NsGraph
  ac : Int
  cb : Int
}

///|
fn build_lr_fanin_case() -> LrFanInCase {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, b, 4, 1))
  let ac = add_edge(graph, a, c, 1, 1)
  let cb = add_edge(graph, c, b, 1, 1)
  { graph, ac, cb }
}

///|
fn require_pre_balance(graph : NsGraph, label : String) -> Unit raise {
  if !network_simplex_pre_balance(graph, 0x7fffffff) {
    fail("\{label}: expected network_simplex_pre_balance to succeed")
  }
}

///|
test "network_simplex LR skips zero-cut tree edges whose entering slack is one" {
  let pre = build_lr_chain_case(3)
  require_pre_balance(pre.graph, "slack-1")

  assert_eq(collect_node_ranks(pre.graph), [0, 1, 3])
  assert_true(is_tree_edge(pre.graph, pre.ab))
  assert_eq(pre.graph.edges[pre.ab].cutvalue, 0)
  assert_eq(enter_edge(pre.graph, pre.ab), Some(pre.bc))
  assert_eq(edge_slack(pre.graph, pre.bc), 1)

  let balanced = build_lr_chain_case(3)
  network_simplex(balanced.graph, 0x7fffffff, BalanceMode::LR)
  assert_eq(collect_node_ranks(balanced.graph), [0, 1, 3])
}

///|
test "network_simplex LR moves a node halfway when the entering slack is even" {
  let pre = build_lr_chain_case(4)
  require_pre_balance(pre.graph, "even-slack")

  assert_eq(collect_node_ranks(pre.graph), [0, 1, 4])
  assert_true(is_tree_edge(pre.graph, pre.ab))
  assert_eq(pre.graph.edges[pre.ab].cutvalue, 0)
  assert_eq(enter_edge(pre.graph, pre.ab), Some(pre.bc))
  assert_eq(edge_slack(pre.graph, pre.bc), 2)

  let balanced = build_lr_chain_case(4)
  network_simplex(balanced.graph, 0x7fffffff, BalanceMode::LR)
  assert_eq(collect_node_ranks(balanced.graph), [0, 2, 4])
}

///|
test "network_simplex LR uses floor division for odd entering slack" {
  let pre = build_lr_odd_slack_diamond_case()
  require_pre_balance(pre.graph, "odd-slack")

  assert_eq(collect_node_ranks(pre.graph), [0, 1, 1, 5])
  assert_true(is_tree_edge(pre.graph, pre.ac))
  assert_eq(pre.graph.edges[pre.ac].cutvalue, 0)
  assert_eq(enter_edge(pre.graph, pre.ac), Some(pre.cd))
  assert_eq(edge_slack(pre.graph, pre.cd), 3)

  let balanced = build_lr_odd_slack_diamond_case()
  network_simplex(balanced.graph, 0x7fffffff, BalanceMode::LR)
  assert_eq(collect_node_ranks(balanced.graph), [0, 1, 2, 5])
}

///|
test "network_simplex LR can move the predecessor side in a fan-in shape" {
  let pre = build_lr_fanin_case()
  require_pre_balance(pre.graph, "fan-in")

  assert_eq(collect_node_ranks(pre.graph), [0, 4, 1])
  assert_true(is_tree_edge(pre.graph, pre.ac))
  assert_eq(pre.graph.edges[pre.ac].cutvalue, 0)
  assert_eq(enter_edge(pre.graph, pre.ac), Some(pre.cb))
  assert_eq(edge_slack(pre.graph, pre.cb), 2)

  let balanced = build_lr_fanin_case()
  network_simplex(balanced.graph, 0x7fffffff, BalanceMode::LR)
  assert_eq(collect_node_ranks(balanced.graph), [0, 4, 2])
}

///|
fn build_disconnected_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  let d = add_node(graph, "d")
  ignore(add_edge(graph, a, b, 1, 1))
  ignore(add_edge(graph, c, d, 1, 1))
  graph
}

///|
test "build_feasible_tree returns false for disconnected components" {
  let graph = build_disconnected_graph()

  assert_false(build_feasible_tree(graph))
}

///|
test "network_simplex_pre_balance returns false for disconnected components" {
  let graph = build_disconnected_graph()

  assert_false(network_simplex_pre_balance(graph, 0x7fffffff))
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
fn build_single_node_graph() -> NsGraph {
  let graph = new_graph()
  ignore(add_node(graph, "solo"))
  graph
}

///|
fn build_symmetric_fanout_graph() -> NsGraph {
  let graph = new_graph()
  let left = add_node(graph, "left")
  let root = add_node(graph, "root")
  let right = add_node(graph, "right")
  ignore(add_edge(graph, root, left, 2, 1))
  ignore(add_edge(graph, root, right, 2, 1))
  graph
}

///|
fn build_asymmetric_fanout_graph() -> NsGraph {
  let graph = new_graph()
  let left = add_node(graph, "left")
  let root = add_node(graph, "root")
  let right = add_node(graph, "right")
  let join = add_node(graph, "join")
  ignore(add_edge(graph, root, left, 2, 1))
  ignore(add_edge(graph, root, right, 2, 1))
  ignore(add_edge(graph, root, join, 2, 1))
  ignore(add_edge(graph, join, right, 2, 1))
  graph
}

///|
fn build_weighted_slack_anchor_graph(
  left_minlen : Int,
  right_minlen : Int,
) -> NsGraph {
  let graph = new_graph()
  let left = add_node(graph, "left")
  let slack = add_node(graph, "slack", kind=NodeKind::Slack)
  let right = add_node(graph, "right")
  ignore(add_edge(graph, slack, left, left_minlen, 1))
  ignore(add_edge(graph, slack, right, right_minlen, 10))
  graph
}

///|
fn build_double_slack_anchor_graph() -> NsGraph {
  let graph = new_graph()
  let target = add_node(graph, "target")
  let left_slack = add_node(graph, "left_slack", kind=NodeKind::Slack)
  let sink = add_node(graph, "sink")
  let right_slack = add_node(graph, "right_slack", kind=NodeKind::Slack)
  ignore(add_edge(graph, left_slack, sink, 0, 10))
  ignore(add_edge(graph, left_slack, target, 4, 1))
  ignore(add_edge(graph, right_slack, sink, 0, 10))
  ignore(add_edge(graph, right_slack, target, 4, 1))
  graph
}

///|
test "build_feasible_tree and pre_balance treat a single node graph as already solved" {
  let tree_graph = build_single_node_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [])

  let balance_graph = build_single_node_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [0])
}

///|
test "build_feasible_tree and pre_balance preserve symmetric source fanout ranks" {
  let tree_graph = build_symmetric_fanout_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [0, 1])

  let balance_graph = build_symmetric_fanout_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [2, 0, 2])
}

///|
test "build_feasible_tree and pre_balance honor downstream fanout constraints" {
  let tree_graph = build_asymmetric_fanout_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [0, 2, 3])

  let balance_graph = build_asymmetric_fanout_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [2, 0, 4, 2])
}

///|
test "build_feasible_tree and pre_balance keep weighted slack anchors tight" {
  let tree_left = build_weighted_slack_anchor_graph(0, 1)
  assert_eq(feasible_tree_edges_for_test(tree_left), [0, 1])

  let balance_left = build_weighted_slack_anchor_graph(0, 1)
  assert_eq(pre_balance_ranks_for_test(balance_left), [0, 0, 1])

  let tree_right = build_weighted_slack_anchor_graph(4, 0)
  assert_eq(feasible_tree_edges_for_test(tree_right), [0, 1])

  let balance_right = build_weighted_slack_anchor_graph(4, 0)
  assert_eq(pre_balance_ranks_for_test(balance_right), [4, 0, 0])
}

///|
test "build_feasible_tree and pre_balance merge duplicate slack anchors" {
  let tree_graph = build_double_slack_anchor_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [1, 0, 2])

  let balance_graph = build_double_slack_anchor_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [4, 0, 0, 0])
}
///|
fn build_lr_flat_label_adjacent_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  set_node_rank(graph, a, 0)
  set_node_rank(graph, b, 72)
  ignore(add_edge(graph, a, b, 128, 1))
  graph
}

///|
fn build_lr_flat_label_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let v0 = add_node(graph, "", kind=NodeKind::Virtual)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  set_node_rank(graph, s0, -1)
  set_node_rank(graph, s1, -55)
  set_node_rank(graph, v0, 0)
  set_node_rank(graph, a, 0)
  set_node_rank(graph, b, 72)
  set_node_rank(graph, c, 144)
  ignore(add_edge(graph, s0, v0, 1, 1))
  ignore(add_edge(graph, s0, c, 1, 1))
  ignore(add_edge(graph, s1, v0, 55, 1))
  ignore(add_edge(graph, s1, a, 1, 1))
  ignore(add_edge(graph, v0, c, 73, 1))
  ignore(add_edge(graph, a, v0, 73, 1))
  ignore(add_edge(graph, a, b, 90, 100))
  ignore(add_edge(graph, b, c, 90, 100))
  graph
}

///|
fn build_lr_compound_clusters_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let s2 = add_node(graph, "", kind=NodeKind::Slack)
  let s3 = add_node(graph, "", kind=NodeKind::Slack)
  let s4 = add_node(graph, "", kind=NodeKind::Slack)
  let s5 = add_node(graph, "", kind=NodeKind::Slack)
  let s6 = add_node(graph, "", kind=NodeKind::Slack)
  let c2n1 = add_node(graph, "C2N1")
  let c1n1 = add_node(graph, "C1N1")
  set_node_rank(graph, s0, 0)
  set_node_rank(graph, s1, 0)
  set_node_rank(graph, s2, 0)
  set_node_rank(graph, s3, 0)
  set_node_rank(graph, s4, 0)
  set_node_rank(graph, s5, 0)
  set_node_rank(graph, s6, -1)
  set_node_rank(graph, c2n1, 0)
  set_node_rank(graph, c1n1, 0)
  ignore(add_edge(graph, s1, s5, 8, 0))
  ignore(add_edge(graph, s1, s3, 8, 0))
  ignore(add_edge(graph, s2, s0, 8, 0))
  ignore(add_edge(graph, s3, s2, 66, 128))
  ignore(add_edge(graph, s3, c2n1, 41, 0))
  ignore(add_edge(graph, s4, s0, 8, 0))
  ignore(add_edge(graph, s5, s4, 66, 128))
  ignore(add_edge(graph, s5, c1n1, 41, 0))
  ignore(add_edge(graph, s6, c1n1, 1, 1))
  ignore(add_edge(graph, s6, c2n1, 1, 1))
  ignore(add_edge(graph, c2n1, s2, 41, 0))
  ignore(add_edge(graph, c1n1, s4, 41, 0))
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
test "network_simplex LR preserves adjacent flat-label spacing" {
  let graph = build_lr_flat_label_adjacent_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [0, 128])
}

///|
test "network_simplex LR preserves non-adjacent flat-label spacing" {
  let graph = build_lr_flat_label_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [73, -17, 74, -16, 74, 164])
}

///|
fn build_lr_compound_clusters_fixture_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "C2N1", kind: NodeKind::Normal, rank: 0 },
      { name: "C1N1", kind: NodeKind::Normal, rank: 0 },
    ],
    [
      { tail: 1, head: 5, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 1, head: 3, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 2, head: 0, minlen: 8, weight: 0, in_pos: 1 },
      { tail: 3, head: 2, minlen: 67, weight: 128, in_pos: 0 },
      { tail: 3, head: 7, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 4, head: 0, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 5, head: 4, minlen: 67, weight: 128, in_pos: 0 },
      { tail: 5, head: 8, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 6, head: 8, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 6, head: 7, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 7, head: 2, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 8, head: 4, minlen: 39, weight: 0, in_pos: 1 },
    ],
  )
}

///|
test "build_feasible_tree and pre_balance preserve compact LR compound cluster spacing" {
  let tree_graph = build_lr_compound_clusters_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [5, 11, 7, 0, 1, 4, 10, 8])

  let balance_graph = build_lr_compound_clusters_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [94, 0, 86, 8, 86, 8, 46, 47, 47])
}

///|
test "network_simplex LR preserves compound cluster spacing" {
  let graph = build_lr_compound_clusters_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [98, 0, 90, 8, 90, 8, 48, 49, 49])
}

///|
struct LrXposNodeSpec {
  kind : NodeKind
  rank : Int
}

///|
struct LrXposEdgeSpec {
  tail : Int
  head : Int
  minlen : Int
  weight : Int
}

///|
fn build_lr_edge_vnode_spacing_graph() -> NsGraph {
  let graph = new_graph()
  let node_specs : Array[LrXposNodeSpec] = [
    { kind: NodeKind::Slack, rank: 49 },
    { kind: NodeKind::Slack, rank: 49 },
    { kind: NodeKind::Slack, rank: 109 },
    { kind: NodeKind::Slack, rank: 109 },
    { kind: NodeKind::Slack, rank: 49 },
    { kind: NodeKind::Slack, rank: 49 },
    { kind: NodeKind::Slack, rank: 24 },
    { kind: NodeKind::Slack, rank: 24 },
    { kind: NodeKind::Slack, rank: 32 },
    { kind: NodeKind::Slack, rank: 32 },
    { kind: NodeKind::Slack, rank: 24 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Slack, rank: -1 },
    { kind: NodeKind::Normal, rank: 0 },
    { kind: NodeKind::Virtual, rank: 0 },
    { kind: NodeKind::Normal, rank: 0 },
    { kind: NodeKind::Virtual, rank: 0 },
    { kind: NodeKind::Normal, rank: 0 },
    { kind: NodeKind::Virtual, rank: 0 },
    { kind: NodeKind::Normal, rank: 0 },
    { kind: NodeKind::Virtual, rank: 25 },
    { kind: NodeKind::Virtual, rank: 55 },
    { kind: NodeKind::Virtual, rank: 33 },
    { kind: NodeKind::Virtual, rank: 55 },
    { kind: NodeKind::Virtual, rank: 25 },
    { kind: NodeKind::Normal, rank: 72 },
    { kind: NodeKind::Virtual, rank: 50 },
    { kind: NodeKind::Normal, rank: 110 },
    { kind: NodeKind::Virtual, rank: 171 },
    { kind: NodeKind::Normal, rank: 110 },
    { kind: NodeKind::Virtual, rank: 50 },
    { kind: NodeKind::Normal, rank: 72 },
  ]
  for idx, spec in node_specs {
    let node = add_node(graph, "n\{idx}", kind=spec.kind)
    set_node_rank(graph, node, spec.rank)
  }

  let edge_specs : Array[LrXposEdgeSpec] = [
    { tail: 0, head: 36, minlen: 1, weight: 2 },
    { tail: 0, head: 35, minlen: 1, weight: 2 },
    { tail: 1, head: 35, minlen: 1, weight: 1 },
    { tail: 1, head: 34, minlen: 1, weight: 1 },
    { tail: 2, head: 34, minlen: 1, weight: 1 },
    { tail: 2, head: 33, minlen: 1, weight: 1 },
    { tail: 3, head: 33, minlen: 1, weight: 1 },
    { tail: 3, head: 32, minlen: 1, weight: 1 },
    { tail: 4, head: 32, minlen: 1, weight: 1 },
    { tail: 4, head: 31, minlen: 1, weight: 1 },
    { tail: 5, head: 31, minlen: 1, weight: 1 },
    { tail: 5, head: 30, minlen: 1, weight: 1 },
    { tail: 6, head: 29, minlen: 1, weight: 1 },
    { tail: 6, head: 30, minlen: 1, weight: 1 },
    { tail: 7, head: 28, minlen: 1, weight: 4 },
    { tail: 7, head: 29, minlen: 1, weight: 4 },
    { tail: 8, head: 27, minlen: 1, weight: 4 },
    { tail: 8, head: 28, minlen: 1, weight: 4 },
    { tail: 9, head: 26, minlen: 1, weight: 4 },
    { tail: 9, head: 27, minlen: 1, weight: 4 },
    { tail: 10, head: 25, minlen: 1, weight: 4 },
    { tail: 10, head: 26, minlen: 1, weight: 4 },
    { tail: 11, head: 23, minlen: 1, weight: 2 },
    { tail: 11, head: 24, minlen: 1, weight: 2 },
    { tail: 12, head: 22, minlen: 1, weight: 1 },
    { tail: 12, head: 23, minlen: 1, weight: 1 },
    { tail: 13, head: 21, minlen: 1, weight: 1 },
    { tail: 13, head: 22, minlen: 1, weight: 1 },
    { tail: 14, head: 20, minlen: 1, weight: 1 },
    { tail: 14, head: 21, minlen: 1, weight: 1 },
    { tail: 15, head: 19, minlen: 1, weight: 1 },
    { tail: 15, head: 20, minlen: 1, weight: 1 },
    { tail: 16, head: 18, minlen: 1, weight: 1 },
    { tail: 16, head: 25, minlen: 1, weight: 1 },
    { tail: 17, head: 18, minlen: 1, weight: 1 },
    { tail: 17, head: 19, minlen: 1, weight: 1 },
    { tail: 18, head: 36, minlen: 72, weight: 0 },
    { tail: 19, head: 25, minlen: 25, weight: 0 },
    { tail: 20, head: 26, minlen: 55, weight: 0 },
    { tail: 21, head: 27, minlen: 33, weight: 0 },
    { tail: 22, head: 28, minlen: 55, weight: 0 },
    { tail: 23, head: 29, minlen: 25, weight: 0 },
    { tail: 24, head: 30, minlen: 72, weight: 0 },
    { tail: 25, head: 35, minlen: 25, weight: 0 },
    { tail: 26, head: 34, minlen: 55, weight: 0 },
    { tail: 27, head: 33, minlen: 139, weight: 0 },
    { tail: 28, head: 32, minlen: 55, weight: 0 },
    { tail: 29, head: 31, minlen: 25, weight: 0 },
  ]
  for spec in edge_specs {
    ignore(add_edge(graph, spec.tail, spec.head, spec.minlen, spec.weight))
  }
  graph
}

///|
test "network_simplex LR preserves integrated edge-vnode spacing ladder" {
  let graph = build_lr_edge_vnode_spacing_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [
    50, 50, 50, 8, -28, -50, -89, -89, -89, -89, -89, -144, -144, -144, -144,
    -144, -109, -129, -108, -128, -143, -143, -143, -143, -143, -88, -88, -88,
    -88, -88, -49, -27, 9, 51, 51, 51, 51,
  ])
}

///|
fn build_lr_edge_labels_fixture_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "", kind: NodeKind::Slack, rank: 71 },
      { name: "", kind: NodeKind::Slack, rank: 71 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "a", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 0 },
      { name: "c", kind: NodeKind::Normal, rank: 0 },
      { name: "b", kind: NodeKind::Normal, rank: 72 },
      { name: "", kind: NodeKind::Virtual, rank: 99 },
      { name: "d", kind: NodeKind::Normal, rank: 72 },
    ],
    [
      { tail: 0, head: 8, minlen: 1, weight: 2, in_pos: 2 },
      { tail: 0, head: 9, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 1, head: 7, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 1, head: 8, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 2, head: 5, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 2, head: 6, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 3, head: 4, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 3, head: 5, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 4, head: 7, minlen: 72, weight: 0, in_pos: 0 },
      { tail: 5, head: 8, minlen: 100, weight: 0, in_pos: 0 },
      { tail: 6, head: 9, minlen: 72, weight: 0, in_pos: 0 },
    ],
  )
}

///|
test "build_feasible_tree and pre_balance preserve compact LR edge-label ladder spacing" {
  let tree_graph = build_lr_edge_labels_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [4, 7, 6, 8, 9, 5, 10, 1, 2])

  let balance_graph = build_lr_edge_labels_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [72, 72, -28, -28, -27, -27, -27, 73, 73, 73])
}

///|
test "network_simplex LR preserves edge-label ladder spacing" {
  let graph = build_lr_edge_labels_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [71, 71, -27, -27, -26, -26, -26, 72, 72, 72])
}

///|
test "network_simplex LR preserves xlabel cluster spacing from TB inputs" {
  let graph = build_lr_xlabels_tb_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [158, 0, 150, 8, 42, 78, 115, 43, 79])
}
