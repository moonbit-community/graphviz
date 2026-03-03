///|
/// Ordering domain: clustered ReMincross rank-group selection helpers used by
/// Stage C cleanup dispatch before rematerialized startpass=2 reorder.

///|
/// Graphviz parity: clustered ReMincross group-selection inputs capture seeded
/// fallback context and vnode-injection context for the current cleanup pass.
pub(all) struct ReMincrossGroupInputs {
  ratio : String
  cluster_order : Array[String]
  ordered_with_vnodes : Map[Int, Array[String]]
  cluster_keys : Map[String, String]
  vnode_group_inputs : ReMincrossVnodeGroupInputs
}

///|
/// Graphviz parity: clustered ReMincross rank groups can seed from current
/// vnode-inclusive order for single-cluster or ratio=fill scenarios, with
/// fallback to full rebuild when seeded output is empty.
pub fn build_remincross_groups(
  inputs : ReMincrossGroupInputs,
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
) -> Map[Int, Array[String]] {
  // Graphviz parity: ratio=fill enables seeded vnode-inclusive reorder input
  // in clustered ReMincross (Graphviz fill-specific branch behavior).
  let prefer_seeded_from_ordered_with_vnodes = inputs.ratio == "fill"
  // Graphviz parity: seeded-group path is considered only when vnode ordering
  // is enabled and graph shape matches single-cluster or ratio=fill scenarios.
  let should_try_seeded =
    inputs.vnode_group_inputs.order_with_vnodes &&
    (inputs.cluster_order.length() == 1 ||
    prefer_seeded_from_ordered_with_vnodes)
  if should_try_seeded {
    let seeded =
      build_seeded_remincross(
        inputs.vnode_group_inputs.final_groups,
        inputs.ordered_with_vnodes,
        inputs.cluster_keys,
      )
    if seeded.length() > 0 {
      return seeded
    }
  }
  // Graphviz parity: clustered ReMincross rebuilt groups come from base real
  // groups plus optional vnode injection with trailing-vnode adjustments.
  build_remincross_vnode_groups(
    inputs.vnode_group_inputs,
    build_vnode_order_keys,
  )
}
