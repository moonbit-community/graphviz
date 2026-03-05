///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
/// Graphviz parity: xpos payload keeps rank/group/cluster snapshots grouped so
/// position.c/cluster.c constraint wiring remains explicit and stable.
priv struct XPositionsInput {
  graph : @cgraph.Graph
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
  flat_label_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions(
  input : XPositionsInput,
) -> Map[String, Double] {
  let graph = input.graph
  let prepared =
    prepare_xpos_constraint_inputs(
      graph,
      input.nodes,
      input.edges,
      input.ranks,
      input.rank_keys,
      input.groups,
      input.sizes,
      input.cluster_keys,
      input.nodesep_pt,
      input.has_edge_labels,
      input.edge_vnodes,
      input.extra_nodes,
      input.flat_label_edges,
    )
  x_positions_from_simplex(
    {
      graph_root: graph,
      nodes: input.nodes,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      edge_out_order: input.edge_out_order,
      nlist_order: input.nlist_order,
      gdnlist_order: input.gdnlist_order,
      ranks: input.ranks,
      rank_keys: input.rank_keys,
      groups: input.groups,
      sizes: input.sizes,
      output_sizes: input.output_sizes,
      cluster_keys: input.cluster_keys,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      extra_nodes: prepared.extra_nodes,
      extra_edges: prepared.extra_edges,
      edge_vnodes: input.edge_vnodes,
      root_ln_targets: prepared.root_ln_targets,
      root_rn_targets: prepared.root_rn_targets,
      compress_width_minlen: prepared.compress_width_minlen,
    },
  )
}
