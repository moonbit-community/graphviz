///|
pub(all) struct XposSimplexSolveInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  sizes : Map[String, @shared.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool
  edge_degree_increment_fn : (@cgraph.Edge) -> Int
  root_margin : Double
  root_compress_weight : Int
  node_left_pt_fn : (String, Map[String, @shared.NodeSize]) -> Double
  node_right_pt_fn : (String, Map[String, @shared.NodeSize]) -> Double
  round_int_fn : (Double) -> Int
  trunc_int_fn : (Double) -> Int
  on_reordered_graph : (@network_simplex.NsGraph, Map[String, Int]) -> Unit
}

///|
/// Graphviz parity: xpos simplex solve consumes the already prepared GD_nlist
/// order, builds/reorders the auxiliary constraint graph, and then runs
/// network_simplex exactly once before reading node ranks.
/// Do not change behavior without updating fixtures/tests.
pub fn solve_xpos_with_simplex(
  input : XposSimplexSolveInput,
) -> Map[String, Double] {
  let constraint_graph =
    build_constraint_graph(
      {
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_out_order: input.edge_out_order,
        nlist_order: input.nlist_order,
        ranks: input.ranks,
        rank_keys: input.rank_keys,
        groups: input.groups,
        sizes: input.sizes,
        cluster_keys: input.cluster_keys,
        nodesep_pt: input.nodesep_pt,
        has_edge_labels: input.has_edge_labels,
        extra_nodes: input.extra_nodes,
        extra_edges: input.extra_edges,
        edge_vnodes: input.edge_vnodes,
        root_ln_targets: input.root_ln_targets,
        root_rn_targets: input.root_rn_targets,
        compress_width_minlen: input.compress_width_minlen,
        segment_minlen: input.segment_minlen_fn,
        edge_has_mid_label: input.edge_has_mid_label_fn,
        edge_degree_increment: input.edge_degree_increment_fn,
        root_margin: input.root_margin,
        root_compress_weight: input.root_compress_weight,
        node_left_pt: input.node_left_pt_fn,
        node_right_pt: input.node_right_pt_fn,
        round_int: input.round_int_fn,
        trunc_int: input.trunc_int_fn,
      },
    )
  // Graphviz parity: constraint graph reorder follows GD_nlist sequence.
  let order =
    build_constraint_reorder(
      {
        graph: constraint_graph.graph,
        index: constraint_graph.index,
        nlist_order: input.nlist_order,
      },
    )
  let reordered =
    reorder_constraint_graph(
      {
        graph: constraint_graph.graph,
        index: constraint_graph.index,
        order,
      },
    )
  (input.on_reordered_graph)(
    reordered.graph,
    reordered.index,
  )
  @network_simplex.network_simplex(
    reordered.graph,
    0x7fffffff,
    @network_simplex.BalanceMode::LR,
  )
  let positions : Map[String, Double] = Map::new()
  for node in input.nodes {
    let name = node.name()
    let idx = reordered.index.get(name).unwrap_or_default()
    positions[name] = @network_simplex.node_rank(reordered.graph, idx).to_double()
  }
  for extra_node in input.extra_nodes {
    let idx = reordered.index.get(extra_node.name).unwrap_or_default()
    positions[extra_node.name] =
      @network_simplex.node_rank(reordered.graph, idx).to_double()
  }
  positions
}
