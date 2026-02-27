///|
/// Extracted from layout_pipeline_stage_c_phase_c5_remincross_nlist_order_helpers.mbt
/// to keep Stage C ReMincross clustered tail-order construction isolated.

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let (cluster_order_seen, names_by_cluster, cluster_first_seen) =
    build_remincross_cluster_order_seen_and_names(
      rem_order_creation,
      rem_cluster_keys,
    )
  let (cluster_order, cluster_order_pos) =
    build_remincross_cluster_order_and_positions(
      cluster_order_seen,
      cluster_first_seen,
      cluster_order_index,
    )
  let heads_by_tail = build_remincross_heads_by_tail(rem_edge_creation)
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    let names = match names_by_cluster.get(cluster) {
      Some(list) => list
      None => []
    }
    if cluster == "" {
      let root_names = match remincross_root_tail_order_override_snapshot.val {
        Some(override_names) =>
          reorder_rank_names_by_override(
            names,
            override_names,
          )
        None => names
      }
      for name in root_names {
        rem_nlist_order.push(name)
      }
      continue
    }
    let nonroot_rank_ordered =
      build_remincross_cluster_tail_order_nonroot_names(
        cluster,
        names,
        rem_ranks,
        heads_by_tail,
        cluster_order_pos,
        cluster_order,
        rem_cluster_keys,
      )
    for name in nonroot_rank_ordered {
      rem_nlist_order.push(name)
    }
  }
  rem_nlist_order
}
