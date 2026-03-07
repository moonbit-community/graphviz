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
  sizes : Map[String, @node_primitives.NodeSize]
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

///|
/// Graphviz parity: x-position solve bridge keeps constraint preparation,
/// simplex-input assembly, and snapshot/order wiring in one boundary helper.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_x_positions_with_prepared_constraints(
  solve_input : XPositionSolveInput,
  cluster_constraint_deps : ClusterConstraintLabelDeps,
  root_margin : Double,
  root_compress_weight : Int,
  segment_minlen_fn : (SlackSegment, Map[String, @cgraph.Node]) -> (Int, Int),
  edge_has_mid_label_fn : (@cgraph.Edge) -> Bool,
  edge_degree_increment_fn : (@cgraph.Edge) -> Int,
  capture_snapshot : Bool,
) -> Map[String, Double] {
  let prepared =
    prepare_xpos_constraint_inputs(
      solve_input.graph,
      solve_input.nodes,
      solve_input.edges,
      solve_input.ranks,
      solve_input.rank_keys,
      solve_input.groups,
      solve_input.sizes,
      solve_input.cluster_keys,
      solve_input.nodesep_pt,
      solve_input.has_edge_labels,
      solve_input.edge_vnodes,
      solve_input.extra_nodes,
      solve_input.flat_label_edges,
      cluster_constraint_deps,
    )
  let order_index = @ordering.build_order_index(solve_input.groups)
  x_positions_from_simplex(
    {
      graph_root: solve_input.graph,
      nodes: solve_input.nodes,
      edges: solve_input.edges,
      edge_tail: solve_input.edge_tail,
      edge_head: solve_input.edge_head,
      edge_out_order: solve_input.edge_out_order,
      nlist_order: solve_input.nlist_order,
      gdnlist_order: solve_input.gdnlist_order,
      ranks: solve_input.ranks,
      rank_keys: solve_input.rank_keys,
      groups: solve_input.groups,
      sizes: solve_input.sizes,
      cluster_keys: solve_input.cluster_keys,
      nodesep_pt: solve_input.nodesep_pt,
      has_edge_labels: solve_input.has_edge_labels,
      extra_nodes: prepared.extra_nodes,
      extra_edges: prepared.extra_edges,
      edge_vnodes: solve_input.edge_vnodes,
      root_ln_targets: prepared.root_ln_targets,
      root_rn_targets: prepared.root_rn_targets,
      compress_width_minlen: prepared.compress_width_minlen,
      root_margin,
      root_compress_weight,
      segment_minlen_fn,
      edge_has_mid_label_fn,
      edge_degree_increment_fn,
      capture_snapshot,
      order_index,
    },
  )
}
