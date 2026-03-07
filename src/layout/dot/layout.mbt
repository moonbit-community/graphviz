///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
/// Stage A validation and option canonicalization now live in input_stage; the
/// root dot package keeps public API error mapping and cross-stage orchestration.

///|
/// Graphviz parity: dot layout orchestration aligned to refs/graphviz/lib/dotgen/dotinit.c
/// (dot_layout/doDot) + lib/common/postproc.c (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  @label_layout.reset_label_caches()
  let prep = match @input_stage.prepare_layout_prep(
    graph,
    {
      rankdir: opts.rankdir,
      nodesep: opts.nodesep,
      ranksep: opts.ranksep,
      splines: opts.splines,
    },
  ) {
    Ok(value) => value
    Err(message) => raise DotLayoutError::InvalidGraph(message~)
  }
  let rank_stage_output =
    @ordering_stage.compute_dot_rank_stage({ graph, prep })
  let rank_data = rank_stage_output.rank_data
  let rank_heights = rank_stage_output.rank_heights
  let cluster_meta = rank_stage_output.cluster_meta
  let ordering = rank_stage_output.ordering
  let positions_state =
    @position_stage.compute_positions(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
      },
    )
  let routing_stage_output =
    @routing_stage.compute_dot_routing_stage(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        positions_state,
      },
      @routing_stage.build_dot_routing_stage_deps(),
    )
  dot_layout_graph_from_layout_tree(
    @finalization.finalize_layout_from_sources(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        positions_state,
        routing_stage_output,
      },
    ),
  )
}
///|
/// Bridge between the public root layout type and the internal shared layout
/// tree used by tree-heavy subpackages.

type LayoutTree = @dot_shared.LayoutTree

///|
fn dot_layout_graph_from_layout_tree(layout : LayoutTree) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(dot_layout_graph_from_layout_tree(subgraph))
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
fn layout_tree_from_dot_layout_graph(layout : DotLayoutGraph) -> LayoutTree {
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(layout_tree_from_dot_layout_graph(subgraph))
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: final writeback preserves Graphviz attribute emission order
/// for graph/node/edge geometry and label positions.
/// Do not change behavior without updating fixtures/tests.
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  @finalization.apply_layout_tree_writeback(
    layout_tree_from_dot_layout_graph(self),
  )
}
