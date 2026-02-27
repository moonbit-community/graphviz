///|
/// Stage B Phase B1/B2 split: rank-data scaffolding
/// helpers for layered ordering preparation.

/// Graphviz parity: edge direction/order comes from acyclic.c for both
/// directed and undirected inputs (dot rank preprocessing orients edges first).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_direction_and_order_maps_for_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (
  Array[String],
  Array[String],
  Array[Bool],
  Map[String, Array[Int]],
  Map[String, Array[Int]],
) {
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let edge_in_order : Map[String, Array[Int]] = Map::new()
  let (tail, head, reversed, out_edges, in_edges) =
    acyclic_edge_directions_with_order(graph, nodes, edges)
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    edge_out_order[name] = out_edges[i].copy()
    edge_in_order[name] = in_edges[i].copy()
  }
  (tail, head, reversed, edge_out_order, edge_in_order)
}



///|
/// Graphviz parity: rank sweep iterates the closed min..max rank interval from
/// sorted rank keys, including missing intermediate ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_all_ranks_span_for_rank_data(rank_keys : Array[Int]) -> Array[Int] {
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  all_ranks
}

///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> RankData {
  let (edge_tail, edge_head, edge_reversed, edge_out_order, _edge_in_order) =
    build_edge_direction_and_order_maps_for_rank_data(graph, nodes, edges)
  let ranks = compute_ranks_directed(
    graph,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
  )
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks = build_all_ranks_span_for_rank_data(rank_keys)
  let self_edge_labels = self_edge_label_half_heights(edges)
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
