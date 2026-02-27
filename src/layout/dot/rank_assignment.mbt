///|
/// Graphviz parity: clustered path branch selection happens before non-cluster
/// base rank assignment, matching rank.c control flow.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  @rank_assignment.compute_ranks_directed(
    source,
    nodes,
    edges,
    has_edge_labels,
    graph_has_cluster,
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) => {
      let _ = graph
      let _ = graph_nodes
      let _ = graph_edges
      @rank_assignment.compute_ranks_directed_base(
        source,
        nodes,
        edges,
        graph_has_edge_labels,
        edge_tail,
        edge_head,
        edge_is_constraint,
        edge_minlen,
        edge_weight,
        (tail_order, edge_creation) => {
          build_graphviz_nlist_order_from_edges(
            tail_order,
            tail_order,
            edge_creation,
            Map::new(),
          )
        },
      )
    },
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) =>
      compute_ranks_directed_with_clusters(
        graph,
        graph_nodes,
        graph_edges,
        graph_has_edge_labels,
      ),
  )
}

///|
/// Rank assignment clustered path: keep cluster setup, solve, and projection
/// logic together so clustered ranking behavior is easier to follow.

///|
/// Graphviz parity: clustered rank assignment keeps non-cluster fallback path
/// and cluster-local/global solve sequence aligned to rank.c behavior.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  @rank_assignment.compute_ranks_directed_with_clusters(
    source,
    nodes,
    edges,
    has_edge_labels,
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) => {
      let (tail, head, _reversed) =
        acyclic_edge_directions(graph, graph_nodes, graph_edges)
      @rank_assignment.compute_ranks_directed_base(
        graph,
        graph_nodes,
        graph_edges,
        graph_has_edge_labels,
        tail,
        head,
        edge_is_constraint,
        edge_minlen,
        edge_weight,
        (tail_order, edge_creation) => {
          build_graphviz_nlist_order_from_edges(
            tail_order,
            tail_order,
            edge_creation,
            Map::new(),
          )
        },
      )
    },
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) => {
      let (tail, head, reversed) =
        acyclic_edge_directions(graph, graph_nodes, graph_edges)
      compute_ranks_directed(
        graph,
        graph_nodes,
        graph_edges,
        graph_has_edge_labels,
        tail,
        head,
        reversed,
      )
    },
    CL_BACK,
    edge_is_constraint,
    edge_minlen,
    edge_weight,
    acyclic_edge_directions_for_names,
  )
}
