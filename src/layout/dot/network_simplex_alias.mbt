///|
type NsGraph = @network_simplex.NsGraph

///|
type BalanceMode = @network_simplex.BalanceMode

///|
type NodeKind = @network_simplex.NodeKind

///|
fn new_graph() -> NsGraph {
  @network_simplex.new_graph()
}

///|
fn add_node(
  graph : NsGraph,
  name : String,
  kind? : NodeKind = NodeKind::Normal,
) -> Int {
  @network_simplex.add_node(graph, name, kind=kind)
}

///|
fn add_edge(
  graph : NsGraph,
  tail : Int,
  head : Int,
  minlen : Int,
  weight : Int,
) -> Int {
  @network_simplex.add_edge(graph, tail, head, minlen, weight)
}

///|
fn node_rank(graph : NsGraph, idx : Int) -> Int {
  @network_simplex.node_rank(graph, idx)
}

///|
fn set_node_rank(graph : NsGraph, idx : Int, rank : Int) -> Unit {
  @network_simplex.set_node_rank(graph, idx, rank)
}

///|
fn network_simplex(graph : NsGraph, max_iter : Int, balance : BalanceMode) -> Unit {
  @network_simplex.network_simplex(graph, max_iter, balance)
}

///|
fn build_feasible_tree(graph : NsGraph) -> Bool {
  @network_simplex.build_feasible_tree(graph)
}
