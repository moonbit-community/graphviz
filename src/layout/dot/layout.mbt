///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
/// Graphviz parity: dot layout orchestration aligned to refs/graphviz/lib/dotgen/dotinit.c
/// (dot_layout/doDot) + lib/common/postproc.c (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  validate_layout_graph(graph)
  @label_layout.reset_label_caches()
  let prep = prepare_layout_inputs(graph, opts)
  let rank_stage_output =
    compute_dot_rank_stage({ graph, prep })
  let rank_data = rank_stage_output.rank_data
  let rank_heights = rank_stage_output.rank_heights
  let cluster_meta = rank_stage_output.cluster_meta
  let ordering = rank_stage_output.ordering
  let positions_state =
    compute_positions(
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
    compute_dot_routing_stage(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        positions_state,
      },
    )
  finalize_layout_graph(
    build_finalize_layout_input_from_sources(
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
