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
