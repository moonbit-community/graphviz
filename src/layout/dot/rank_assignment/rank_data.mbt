///|
pub const CL_BACK : Int = 10

///|
/// Graphviz parity: rank-data payload keeps Stage-B rank inputs grouped so
/// edge direction/orientation wiring remains explicit and stable.
pub struct RankDataInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_edge_labels : Bool
  back_weight_scale : Int
  edge_label_height_pt_for : (@cgraph.Edge) -> Double
}

///|
pub fn make_rank_data_input(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
  edge_label_height_pt_for : (@cgraph.Edge) -> Double,
) -> RankDataInput {
  {
    graph,
    nodes,
    edges,
    has_edge_labels,
    back_weight_scale,
    edge_label_height_pt_for,
  }
}

///|
pub struct RankData {
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  self_edge_labels : Map[String, Double]
}

///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to
/// refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_rank_data(
  input : RankDataInput,
) -> RankData {
  let graph = input.graph
  let nodes = input.nodes
  let edges = input.edges
  // Graphviz parity: edge direction/order comes from acyclic.c for both
  // directed and undirected inputs (dot rank preprocessing orients edges first).
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let acyclic_directions =
    acyclic_edge_directions_with_order(graph, nodes, edges)
  let edge_tail = acyclic_directions.tail
  let edge_head = acyclic_directions.head
  let edge_reversed = acyclic_directions.reversed
  let out_edges = acyclic_directions.out_edges
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
  }
  let ranks = compute_ranks_directed(
    graph,
    nodes,
    edges,
    input.has_edge_labels,
    edge_tail,
    edge_head,
    input.back_weight_scale,
  )
  let groups = @ordering.build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  // Graphviz parity: rank sweep iterates the closed min..max rank interval
  // from sorted rank keys, including missing intermediate ranks.
  let all_ranks = @positioning.build_all_ranks_with_overlays(rank_keys, [])
  let self_edge_labels =
    @positioning.self_edge_label_half_heights(
      edges,
      input.edge_label_height_pt_for,
    )
  {
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    self_edge_labels,
  }
}
