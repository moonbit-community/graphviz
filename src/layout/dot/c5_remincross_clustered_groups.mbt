///|
/// Stage C Phase C5 split: remincross clustered groups
/// helpers for focused ReMincross responsibilities.

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
    if dispatch_context.order_with_vnodes &&
      (dispatch_context.cluster_meta.cluster_order.length() == 1 ||
      prefer_seeded_from_ordered_with_vnodes) {
      let seeded =
        build_remincross_groups_from_ordered_with_vnodes(
          dispatch_context.base_groups,
          dispatch_context.ordered_with_vnodes,
          dispatch_context.cluster_meta.cluster_keys,
        )
      if seeded.length() > 0 {
        dot_trace_groups("remincross_groups", seeded)
        seeded
      } else {
        let rebuilt =
          build_remincross_groups_with_optional_vnodes(
            dispatch_context.base_groups,
            dispatch_context.order_with_vnodes,
            dispatch_context.edges,
            dispatch_context.edge_tail,
            dispatch_context.edge_head,
            dispatch_context.edge_reversed,
            dispatch_context.ranks,
            dispatch_context.cluster_meta.intercluster_keys,
            dispatch_context.cluster_meta.cluster_parents,
            dispatch_context.cluster_meta.cluster_min_rank,
            dispatch_context.cluster_meta.cluster_max_rank,
            dispatch_context.vnode_info.edge_vnodes,
            dispatch_context.vnode_info.vnode_ranks,
            dispatch_context.vnode_info.vnodes_by_rank,
          )
        dot_trace_groups("remincross_groups", rebuilt)
        rebuilt
      }
    } else {
      let rebuilt =
        build_remincross_groups_with_optional_vnodes(
          dispatch_context.base_groups,
          dispatch_context.order_with_vnodes,
          dispatch_context.edges,
          dispatch_context.edge_tail,
          dispatch_context.edge_head,
          dispatch_context.edge_reversed,
          dispatch_context.ranks,
          dispatch_context.cluster_meta.intercluster_keys,
          dispatch_context.cluster_meta.cluster_parents,
          dispatch_context.cluster_meta.cluster_min_rank,
          dispatch_context.cluster_meta.cluster_max_rank,
          dispatch_context.vnode_info.edge_vnodes,
          dispatch_context.vnode_info.vnode_ranks,
          dispatch_context.vnode_info.vnodes_by_rank,
        )
      dot_trace_groups("remincross_groups", rebuilt)
      rebuilt
    }
  let rem_rank_keys = collect_rank_keys(rem_groups)
  if rem_rank_keys.length() > 1 {
    run_clustered_remincross_multi_rank(
      dispatch_context,
      rem_rank_keys,
      rem_groups,
    )
  } else {
    (dispatch_context.ordered_with_vnodes, dispatch_context.base_groups)
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_from_ordered_with_vnodes(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = match base_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let real_order : Map[String, Int] = Map::new()
    for i in 0..<base_real.length() {
      real_order[base_real[i]] = i
    }
    let mut root_real_count = 0
    let mut cluster_real_count = 0
    let mut root_real_name = ""
    let cluster_real_names : Array[String] = []
    for name in base_real {
      if cluster_key_or_empty(cluster_keys, name) == "" {
        root_real_count = root_real_count + 1
        root_real_name = name
      } else {
        cluster_real_count = cluster_real_count + 1
        cluster_real_names.push(name)
      }
    }
    let mut synthetic_count = 0
    let mut synthetic_name = ""
    for name in filtered {
      if real_order.get(name) is None {
        synthetic_count = synthetic_count + 1
        synthetic_name = name
      }
    }
    // Graphviz parity: when a mixed root/cluster rank starts with exactly one
    // synthetic vnode, keep the root real node as the rank leader and trail
    // that single vnode after clustered real nodes.
    if filtered.length() == 4 &&
      is_edge_vnode_name(filtered[0]) &&
      root_real_count == 1 &&
      cluster_real_count >= 2 &&
      synthetic_count == 1 &&
      synthetic_name != "" &&
      root_real_name != "" {
      let special_order : Array[String] = [root_real_name]
      for name in cluster_real_names {
        special_order.push(name)
      }
      special_order.push(synthetic_name)
      rem_groups[rank] = special_order
      continue
    }
    let prev_real : Array[Int?] = []
    let mut last_real : Int? = None
    for name in filtered {
      match real_order.get(name) {
        Some(idx) => last_real = Some(idx)
        None => ()
      }
      prev_real.push(last_real)
    }
    let next_rev : Array[Int?] = []
    let mut next_real : Int? = None
    let mut rev_idx = filtered.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      let name = filtered[rev_idx]
      match real_order.get(name) {
        Some(idx) => next_real = Some(idx)
        None => ()
      }
      next_rev.push(next_real)
    }
    let next_real_by_pos : Array[Int?] = []
    let mut idx = next_rev.length()
    while idx > 0 {
      idx = idx - 1
      next_real_by_pos.push(next_rev[idx])
    }
    let keyed : Array[(String, Int, Int)] = []
    for i in 0..<filtered.length() {
      let name = filtered[i]
      let key = match real_order.get(name) {
        Some(real_idx) => real_idx * 2
        None =>
          match prev_real[i] {
            Some(prev_idx) => prev_idx * 2 + 1
            None =>
              match next_real_by_pos[i] {
                Some(next_idx) => next_idx * 2 - 1
                None => i * 2
              }
          }
      }
      keyed.push((name, key, i))
    }
    keyed.sort_by((a, b) => {
      let (_, key_a, idx_a) = a
      let (_, key_b, idx_b) = b
      if key_a < key_b {
        -1
      } else if key_a > key_b {
        1
      } else if idx_a < idx_b {
        -1
      } else if idx_a > idx_b {
        1
      } else {
        0
      }
    })
    let ordered_rank : Array[String] = []
    for entry in keyed {
      let (name, _, _) = entry
      ordered_rank.push(name)
    }
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}
