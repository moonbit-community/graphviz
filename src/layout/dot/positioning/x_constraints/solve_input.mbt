///|
/// Graphviz parity: x-position solve input keeps reordered rank metadata,
/// vnode extra-node toggles, and size overlays grouped for one xpos call.
pub struct XposComputationInput {
  x_sizes : Map[String, @node_primitives.NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: xpos source bundle keeps x-stage payload and vnode replay
/// metadata grouped so Stage D call-sites avoid positional drift.
priv struct XposComputationInputSources {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @node_primitives.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: xpos solver inputs preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input_from_sources(
  sources : XposComputationInputSources,
) -> XposComputationInput {
  let x_sizes =
    if sources.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(
        sources.x_base_sizes,
        sources.vnode_sizes,
      )
    } else {
      sources.x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(sources.x_groups)
  let x_ranks = @ordering.build_node_ranks(sources.x_groups)
  let vnode_extra_nodes =
    if sources.use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        sources.vnode_creation_order,
        sources.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if sources.use_vnodes_for_xpos {
      sources.edge_vnodes
    } else {
      Map::new()
    }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: xpos solver callback input keeps one compute_x_positions
/// invocation payload grouped so stage wiring avoids positional drift.
pub(all) struct XPositionSolveInput {
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
  sizes : Map[String, @node_primitives.NodeSize]
  output_sizes : Map[String, @node_primitives.NodeSize]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  extra_nodes : Array[@ordering.ExtraConstraintNode]
  flat_label_edges : Array[ConstraintEdge]
  edge_vnodes : Map[String, Array[String]]
}

///|
/// Graphviz parity: x-position pipeline input keeps x-seed + vnode replay
/// snapshots and one compute_x_positions callback payload at one boundary.
pub(all) struct XPositionPipelineInput {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, @node_primitives.NodeSize]
  x_groups : Map[Int, Array[String]]
  vnode_sizes : Map[String, @node_primitives.NodeSize]
  vnode_creation_order : Array[String]
  vnode_ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  cluster_keys : Map[String, String]
  nodesep_pt : Double
  has_edge_labels : Bool
  output_sizes : Map[String, @node_primitives.NodeSize]
  flat_label_edges : Array[ConstraintEdge]
}

///|
/// Graphviz parity: x-position stage keeps vnode merge and rank-derivation
/// order unchanged while producing one stable solve payload.
/// Do not change behavior without updating fixtures/tests.
pub fn build_x_position_solve_input(
  input : XPositionPipelineInput,
) -> XPositionSolveInput {
  let xpos_input =
    build_xpos_computation_input_from_sources(
      {
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        x_base_sizes: input.x_base_sizes,
        x_groups: input.x_groups,
        vnode_sizes: input.vnode_sizes,
        vnode_creation_order: input.vnode_creation_order,
        vnode_ranks: input.vnode_ranks,
        edge_vnodes: input.edge_vnodes,
      },
    )
  {
    graph: input.graph,
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_out_order: input.edge_out_order,
    nlist_order: input.nlist_order,
    gdnlist_order: input.gdnlist_order,
    ranks: xpos_input.x_ranks,
    rank_keys: xpos_input.x_rank_keys,
    groups: input.x_groups,
    sizes: xpos_input.x_sizes,
    output_sizes: input.output_sizes,
    cluster_keys: input.cluster_keys,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    extra_nodes: xpos_input.x_extra_nodes,
    flat_label_edges: input.flat_label_edges,
    edge_vnodes: xpos_input.x_edge_vnodes,
  }
}

