///|
/// Positioning domain: x-position constraint input preparation helpers.

///|
pub(all) struct PreparedXposConstraintInputs {
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
}

///|
pub fn prepare_xpos_constraint_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @shared.NodeSize],
  cluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  edge_vnodes : Map[String, Array[String]],
  base_extra_nodes : Array[@ordering.ExtraConstraintNode],
  flat_label_edges : Array[ConstraintEdge],
  cluster_constraint_deps : ClusterConstraintLabelDeps,
) -> PreparedXposConstraintInputs {
  let cluster_constraints =
    build_cluster_constraints(
      graph,
      nodes,
      edges,
      ranks,
      rank_keys,
      groups,
      sizes,
      cluster_keys,
      nodesep_pt,
      has_edge_labels,
      edge_vnodes,
      cluster_constraint_deps,
    )
  let all_extra_nodes = base_extra_nodes.copy()
  for pair in cluster_constraints.extra_nodes {
    all_extra_nodes.push(pair)
  }
  let all_extra_edges = cluster_constraints.extra_edges.copy()
  for edge in flat_label_edges {
    all_extra_edges.push(edge)
  }
  let rankdir = @shared.graph_rankdir(graph)
  let compress_width_minlen = compress_width_minlen_pt(graph, rankdir)
  let all_root_ln_targets = cluster_constraints.root_ln_targets.copy()
  let all_root_rn_targets = cluster_constraints.root_rn_targets.copy()
  match compress_width_minlen {
    Some(_) => {
      // Graphviz parity: contain_nodes constrains per-rank leftmost/rightmost
      // nodes against root ln/rn before adding the compress edge.
      append_missing_rank_boundary_targets(
        rank_keys,
        groups,
        all_root_ln_targets,
        all_root_rn_targets,
      )
    }
    None => ()
  }
  {
    extra_nodes: all_extra_nodes,
    extra_edges: all_extra_edges,
    root_ln_targets: all_root_ln_targets,
    root_rn_targets: all_root_rn_targets,
    compress_width_minlen,
  }
}
