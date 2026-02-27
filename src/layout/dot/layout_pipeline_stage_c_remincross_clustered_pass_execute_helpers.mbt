///|
/// Remaining Stage C clustered ReMincross pass execution helper after
/// extracting dispatch/output/group/materialize/reorder helper modules.

///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_pass(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let tail_order =
      collect_unique_tail_order_from_edge_tail_sequence(dispatch_context.edge_tail)
    let tail_order_joined = tail_order.join(" ")
    println("remincross source_tail_order \{tail_order_joined}")
  }
  let prefer_seeded_from_ordered_with_vnodes =
    match dispatch_context.graph.get_attr("ratio") {
      Some(value) => value == "fill"
      None => false
    }
  let rem_groups =
    build_clustered_remincross_pass_groups(
      dispatch_context.ordered_with_vnodes,
      dispatch_context.base_groups,
      dispatch_context.order_with_vnodes,
      prefer_seeded_from_ordered_with_vnodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_reversed,
      dispatch_context.ranks,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
    )
  let (next_ordered_with_vnodes, next_final_groups) =
    build_clustered_remincross_pass_groups_output_from_rem_groups(
      dispatch_context,
      rem_groups,
    )
  build_clustered_remincross_pass_output(next_ordered_with_vnodes, next_final_groups)
}
