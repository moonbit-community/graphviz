///|
/// Positioning domain: x-position simplex solve pipeline bridge.
pub(all) struct XSimplexInput {
  graph_root : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
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
  root_margin : Double
  root_compress_weight : Int
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int)
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool
  edge_degree_increment_fn : (@cgraph.Edge) -> Int
  capture_snapshot : Bool
  order_index : Map[String, Int]
}

pub fn x_positions_from_simplex(input : XSimplexInput) -> Map[String, Double] {
  let xpos_nlist_order =
    build_xpos_nlist_order(
      {
        rankdir: @shared.graph_rankdir(input.graph_root),
        nlist_order: input.nlist_order,
        gdnlist_order: input.gdnlist_order,
        cluster_keys: input.cluster_keys,
        rank_keys: input.rank_keys,
        groups: input.groups,
      },
    )
  solve_xpos_with_simplex(
    {
      nodes: input.nodes,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      edge_out_order: input.edge_out_order,
      nlist_order: xpos_nlist_order,
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
      segment_minlen_fn: input.segment_minlen_fn,
      edge_has_mid_label_fn: input.edge_has_mid_label_fn,
      edge_degree_increment_fn: input.edge_degree_increment_fn,
      root_margin: input.root_margin,
      root_compress_weight: input.root_compress_weight,
      on_reordered_graph:
        (graph, index) =>
          if input.capture_snapshot {
            xpos_constraint_snapshot.val = Some(
              build_constraint_snapshot(
                graph,
                index,
                input.sizes,
                input.order_index,
              ),
            )
          },
    },
  )
}
