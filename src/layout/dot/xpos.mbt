///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
const CLUSTER_COMPACT_WEIGHT : Int = 128

///|
const ROOT_COMPRESS_WEIGHT : Int = 1000

///|
fn cluster_label_borders_for_xpos_constraints(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> (Double, Double) {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if !flip {
    return (0.0, 0.0)
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let border = metrics.height_pt + CLUSTER_LABEL_PAD_PT
      match graph_label_loc(graph) {
        LabelLoc::Top => (0.0, border)
        LabelLoc::Bottom => (border, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
/// Graphviz parity: xpos payload keeps rank/group/cluster snapshots grouped so
/// position.c/cluster.c constraint wiring remains explicit and stable.
type XPositionsInput = @positioning.XPositionSolveInput

///|
type ConstraintEdge = @positioning.ConstraintEdge

///|
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

///|
fn x_positions_from_simplex(input : XSimplexInput) -> Map[String, Double] {
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
    @positioning.cluster_margin_pt(input.nodes[0].graph())
  } else {
    CLUSTER_MARGIN_PT
  }
  @positioning.x_positions_from_simplex(
    {
      graph_root: input.graph_root,
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
      cluster_keys: input.cluster_keys,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      extra_nodes: input.extra_nodes,
      extra_edges: input.extra_edges,
      edge_vnodes: input.edge_vnodes,
      root_ln_targets: input.root_ln_targets,
      root_rn_targets: input.root_rn_targets,
      compress_width_minlen: input.compress_width_minlen,
      root_margin,
      root_compress_weight: ROOT_COMPRESS_WEIGHT,
      segment_minlen_fn:
        (segment, real_by_name) =>
          @positioning.segment_slack_minlen(
            segment,
            (node_name, port) =>
              edge_port_offset(
                node_name,
                port,
                port_offsets,
                input.sizes,
                rankdir,
                real_by_name,
              ),
          ),
      edge_has_mid_label_fn: edge => edge_mid_label_metrics(edge) is Some(_),
      edge_degree_increment_fn:
        edge =>
          if @dot_shared.edge_dir_for(edge, edge.tail().graph().kind()) is @dot_shared.EdgeDir::Both {
            2
          } else {
            1
          },
      capture_snapshot: @positioning.should_capture_xpos_snapshot(input.graph_root),
      order_index,
    },
  )
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/position.c + cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions(
  input : XPositionsInput,
) -> Map[String, Double] {
  let graph = input.graph
  let prepared =
    @positioning.prepare_xpos_constraint_inputs(
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
      {
        cluster_label_borders_for: cluster_label_borders_for_xpos_constraints,
        cluster_label_width_with_pad_for: cluster_label_width_with_pad_for_layout,
        cluster_compact_weight: CLUSTER_COMPACT_WEIGHT,
      },
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
