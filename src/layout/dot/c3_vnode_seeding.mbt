///|
/// Stage C Phase C3 split: vnode interpolation seeding wrapper for local
/// cluster rank-group reorder passes.

///|
/// Graphviz parity: cluster-local mincross seeds ND_order by vnode
/// interpolation, then applies same-rank flat constraints before startpass=2.
fn build_cluster_rank_seeded_groups(
  local_context : @ordering.ClusterLocalReorderContext,
  input_phase_output : @ordering.ClusterLocalReorderRunInputsOutput,
  fixed_ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let seeded_by_vnode_interp =
    @ordering.seed_local_groups_by_vnode(
      local_context.cluster_rank_keys,
      local_context.cluster_groups,
      fixed_ranks,
      input_phase_output.parents,
      input_phase_output.children,
    )
  // Graphviz parity: mincross_clust() runs flat_reorder before mincross(g,2).
  @ordering.flat_reorder_rank_groups(
    local_context.cluster_rank_keys,
    seeded_by_vnode_interp,
    fixed_ranks,
    input_phase_output.cluster_flat_constraints,
    false,
  )
}
