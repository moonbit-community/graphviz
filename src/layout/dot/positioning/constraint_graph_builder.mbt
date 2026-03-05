///|
pub(all) struct ConstraintGraphBuildInput {
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
  segment_minlen : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label : (@cgraph.Edge) -> Bool
  edge_degree_increment : (@cgraph.Edge) -> Int
  root_margin : Double
  root_compress_weight : Int
  node_left_pt : (String, Map[String, @shared.NodeSize]) -> Double
  node_right_pt : (String, Map[String, @shared.NodeSize]) -> Double
  round_int : (Double) -> Int
  trunc_int : (Double) -> Int
}

///|
pub(all) struct ConstraintGraphBuildOutput {
  graph : @network_simplex.NsGraph
  index : Map[String, Int]
}

///|
/// Graphviz parity: constraint graph uses GD_nlist order for existing
/// nodes and appends aux slack/cluster nodes per create_aux_edges.
/// Do not change behavior without updating fixtures/tests.
pub fn build_constraint_graph(
  input : ConstraintGraphBuildInput,
) -> ConstraintGraphBuildOutput {
  let graph = @network_simplex.new_graph()
  let skip_intercluster =
    @sys.get_env_var("DOT_SKIP_INTERCLUSTER_XPOS") is Some(_)
  let base_positions = compute_rank_positions(
    input.rank_keys,
    input.groups,
    input.sizes,
    input.nodesep_pt,
    input.has_edge_labels,
  )
  let node_setup =
    build_constraint_nodes_setup(
      {
        graph,
        nodes: input.nodes,
        extra_nodes: input.extra_nodes,
        nlist_order: input.nlist_order,
        base_positions,
        trunc_int: input.trunc_int,
      },
    )
  let index = node_setup.index
  let rank_constraint_seed =
    build_rank_constraint_seed(
      input.rank_keys,
      input.groups,
      input.sizes,
      input.nodesep_pt,
      input.has_edge_labels,
    )
  let rank_adj_constraints = rank_constraint_seed.rank_adj_constraints
  let rank_adj_order = rank_constraint_seed.rank_adj_order
  let segment_pass =
    build_constraint_segment_pass(
      {
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_out_order: input.edge_out_order,
        nlist_order: input.nlist_order,
        ranks: input.ranks,
        cluster_keys: input.cluster_keys,
        edge_vnodes: input.edge_vnodes,
        order_in_rank: rank_constraint_seed.order_in_rank,
        nodesep_pt: input.nodesep_pt,
        sizes: input.sizes,
        skip_intercluster,
        rank_adj_constraints,
        edge_has_mid_label: input.edge_has_mid_label,
        edge_degree_increment: input.edge_degree_increment,
        trunc_int: input.trunc_int,
      },
    )
  for key in rank_adj_order {
    match rank_adj_constraints.get(key) {
      Some(entry) => add_constraint_edge_if_present(graph, index, entry)
      None => ()
    }
  }
  for _flat_key, entry in segment_pass.flat_minlen_constraints {
    add_constraint_edge_if_present(graph, index, entry)
  }
  add_segments_in_tail_order(
    {
      graph,
      index,
      segments_by_tail: segment_pass.segments_by_tail,
      nlist_order: input.nlist_order,
      segment_minlen:
        segment =>
          (input.segment_minlen)(
            segment,
            node_setup.real_by_name,
          ),
    },
  )
  append_late_constraint_nodes(
    {
      graph,
      index,
      late_extra_nodes: node_setup.late_extra_nodes,
    },
  )
  add_root_boundary_constraints(
    {
      graph,
      index,
      root_ln_targets: input.root_ln_targets,
      root_rn_targets: input.root_rn_targets,
      sizes: input.sizes,
      root_margin: input.root_margin,
      compress_width_minlen: input.compress_width_minlen,
      root_compress_weight: input.root_compress_weight,
      node_left_pt: input.node_left_pt,
      node_right_pt: input.node_right_pt,
      round_int: input.round_int,
    },
  )
  for edge in input.extra_edges {
    let _ = edge.tail_port
    let _ = edge.head_port
    add_constraint_edge_if_present(graph, index, edge)
  }
  { graph, index }
}
