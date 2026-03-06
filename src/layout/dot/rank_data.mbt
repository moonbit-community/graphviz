///|
/// Stage B stage-local type definitions shared by rank assignment and
/// rank-height assembly.

///|
/// Graphviz parity: rank-data payload keeps stage-B rank inputs grouped so
/// edge direction/orientation wiring remains explicit and stable.
priv struct RankDataInput {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_edge_labels : Bool
}

///|
priv struct RankData {
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
priv struct RankHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  ranksep_pt : Double
}

///|
/// Stage B rank-data scaffolding helpers for layered ordering preparation.

///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_data(
  input : RankDataInput,
) -> RankData {
  let graph = input.graph
  let nodes = input.nodes
  let edges = input.edges
  // Graphviz parity: edge direction/order comes from acyclic.c for both
  // directed and undirected inputs (dot rank preprocessing orients edges first).
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let acyclic_directions =
    @rank_assignment.acyclic_edge_directions_with_order(graph, nodes, edges)
  let edge_tail = acyclic_directions.tail
  let edge_head = acyclic_directions.head
  let edge_reversed = acyclic_directions.reversed
  let out_edges = acyclic_directions.out_edges
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
  }
  let ranks = @rank_assignment.compute_ranks_directed(
    graph,
    nodes,
    edges,
    input.has_edge_labels,
    edge_tail,
    edge_head,
    CL_BACK,
  )
  let groups = @ordering.build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  // Graphviz parity: rank sweep iterates the closed min..max rank interval
  // from sorted rank keys, including missing intermediate ranks.
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels =
    @positioning.self_edge_label_half_heights(
      edges,
      edge => edge_label_height_pt(edge),
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
