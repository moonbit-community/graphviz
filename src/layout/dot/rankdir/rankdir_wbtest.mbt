///|
test "parse_rankdir accepts graphviz aliases" {
  assert_eq(parse_rankdir("TB"), Some(RankDir::TB))
  assert_eq(parse_rankdir("bt"), Some(RankDir::BT))
  assert_eq(parse_rankdir("Lr"), Some(RankDir::LR))
  assert_eq(parse_rankdir("rl"), Some(RankDir::RL))
  assert_eq(parse_rankdir("diag"), None)
}

///|
test "graph_rankdir walks parent chain" {
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=RL; subgraph cluster_outer { subgraph cluster_inner { a -> b } } }",
  )
  assert_eq(graph_rankdir(graph), RankDir::RL)

  let outer = graph.subgraphs()[0]
  let inner = outer.subgraphs()[0]
  assert_eq(graph_rankdir(outer), RankDir::RL)
  assert_eq(graph_rankdir(inner), RankDir::RL)

  let no_rankdir = @dot_parser.parse_dot("digraph { a -> b }")
  assert_eq(graph_rankdir(no_rankdir), RankDir::TB)
}
