///|
type ConstraintEdge = @positioning.ConstraintEdge

priv struct XSimplexInput {
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
  sizes : Map[String, NodeSize]
  output_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  extra_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
  root_ln_targets : Array[String]
  root_rn_targets : Array[String]
  compress_width_minlen : Int?
}

fn x_positions_from_simplex(input : XSimplexInput) -> Map[String, Double] {
  let xpos_nlist_order =
    @positioning.build_xpos_nlist_order(
      {
        rankdir: @dot_shared.graph_rankdir(input.graph_root),
        nlist_order: input.nlist_order,
        gdnlist_order: input.gdnlist_order,
        cluster_keys: input.cluster_keys,
        rank_keys: input.rank_keys,
        groups: input.groups,
      },
    )
  let order_index = @ordering.build_order_index(input.groups)
  let mut has_port_edges = false
  for edge in input.edges {
    if @dot_shared.port_is_explicit(edge.tail_port()) || @dot_shared.port_is_explicit(edge.head_port()) {
      has_port_edges = true
      break
    }
  }
  let port_offsets =
    if has_port_edges {
      port_offsets_for_nodes(input.nodes, input.output_sizes)
    } else {
      Map::new()
    }
  let rankdir =
    if input.nodes.length() > 0 {
      @dot_shared.graph_rankdir(input.nodes[0].graph())
    } else {
      RankDir::TB
    }
  let root_margin = if input.nodes.length() > 0 {
    cluster_margin_pt(input.nodes[0].graph())
  } else {
    CLUSTER_MARGIN_PT
  }
  @positioning.solve_xpos_with_simplex(
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
      segment_minlen_fn:
        (segment, real_by_name) =>
          segment_slack_minlen(
            segment,
            port_offsets,
            input.sizes,
            rankdir,
            real_by_name,
          ),
      edge_has_mid_label_fn: edge => edge_mid_label_metrics(edge) is Some(_),
      edge_degree_increment_fn:
        edge =>
          if @dot_shared.edge_dir_for(edge, edge.tail().graph().kind()) is @dot_shared.EdgeDir::Both {
            2
          } else {
            1
          },
      root_margin,
      root_compress_weight: ROOT_COMPRESS_WEIGHT,
      node_left_pt_fn: @dot_shared.node_left_pt,
      node_right_pt_fn: @dot_shared.node_right_pt,
      round_int_fn: round_int,
      trunc_int_fn: trunc_int,
      on_reordered_graph:
        (graph, index) =>
          if @positioning.should_capture_xpos_snapshot(input.graph_root) {
            @positioning.xpos_constraint_snapshot.val = Some(
              @positioning.build_constraint_snapshot(
                graph,
                index,
                input.sizes,
                order_index,
              ),
            )
          },
    },
  )
}
