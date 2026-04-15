// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
test "sort_nodes_by_rank preserves original order within equal-rank groups" {
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
  let nodes = [n4, n2, n0, n3, n1]

  sort_nodes_by_rank(graph, nodes)

  assert_eq(nodes, [n3, n1, n4, n2, n0])
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
