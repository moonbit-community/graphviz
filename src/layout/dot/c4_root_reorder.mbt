///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.


///|
/// Graphviz parity: root-anchor transfer only applies on the single-left
/// cluster hand-off shape from the previous rank map.
fn select_root_left_anchor(
  order_map : Map[String, Int],
  previous_order_map : Map[String, Int]?,
) -> String? {
  let prev_map = match previous_order_map {
    Some(value) => value
    None => return None
  }
  let prev_root = match prev_map.get("") {
    Some(value) => value
    None => return None
  }
  let mut prev_cluster_count = 0
  let mut left_anchor : String? = None
  let mut left_order = 0
  let mut has_left = false
  let mut has_right = false
  for cluster, order in prev_map {
    if cluster == "" {
      continue
    }
    prev_cluster_count = prev_cluster_count + 1
    if order_map.get(cluster) is None {
      continue
    }
    if order < prev_root {
      if !has_left || order > left_order {
        left_anchor = Some(cluster)
        left_order = order
        has_left = true
      }
    } else if order > prev_root {
      has_right = true
    }
  }
  // Guardrail: only apply this on the simple single-left-anchor shape
  // seen in cluster hand-off ranks (e.g. clust5 rank transition).
  if prev_cluster_count != 1 || !has_left || has_right {
    return None
  }
  left_anchor
}

///|
/// Graphviz parity: cluster-rank sort keys are normalized into deterministic
/// non-root order by (order, cluster-name) before root-anchor transfer.
fn build_sorted_non_root_clusters(
  order_map : Map[String, Int],
) -> Array[String] {
  let entries : Array[(Int, String)] = []
  for cluster, order in order_map {
    if cluster == "" {
      continue
    }
    entries.push((order, cluster))
  }
  if entries.length() > 1 {
    entries.sort_by((a, b) => {
      let (a_order, a_cluster) = a
      let (b_order, b_cluster) = b
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else if a_cluster < b_cluster {
        -1
      } else if a_cluster > b_cluster {
        1
      } else {
        0
      }
    })
  }
  let sorted_clusters : Array[String] = []
  for entry in entries {
    let (_order, cluster) = entry
    sorted_clusters.push(cluster)
  }
  sorted_clusters
}

///|
/// Graphviz parity: root-anchor transfer inserts root bucket immediately
/// after the selected left-anchor cluster in sorted non-root order.
fn build_root_anchor_reordered_clusters(
  sorted_clusters : Array[String],
  left_anchor : String,
) -> Array[String] {
  let mut insert_idx = sorted_clusters.length()
  for i in 0..<sorted_clusters.length() {
    if sorted_clusters[i] == left_anchor {
      insert_idx = i + 1
      break
    }
  }
  let reordered : Array[String] = []
  for i in 0..<sorted_clusters.length() {
    if i == insert_idx {
      reordered.push("")
    }
    reordered.push(sorted_clusters[i])
  }
  if insert_idx >= sorted_clusters.length() {
    reordered.push("")
  }
  reordered
}

///|
fn rewrite_cluster_order_map(
  order_map : Map[String, Int],
  ordered_clusters : Array[String],
) -> Unit {
  let mut idx = 0
  for cluster in ordered_clusters {
    order_map[cluster] = idx
    idx = idx + 1
  }
}

///|
/// Graphviz parity: root real-node bucket keeps relative left/right anchor
/// continuity across adjacent ranks when both ranks expose root buckets.
/// Do not change behavior without updating fixtures/tests.
fn anchor_root_bucket(
  order_map : Map[String, Int],
  previous_order_map : Map[String, Int]?,
) -> Unit {
  if order_map.get("") is None {
    return ()
  }
  let left_anchor = match select_root_left_anchor(
    order_map,
    previous_order_map,
  ) {
    Some(value) => value
    None => return ()
  }
  let sorted_clusters = build_sorted_non_root_clusters(order_map)
  if sorted_clusters.length() == 0 {
    return ()
  }
  let reordered_clusters =
    build_root_anchor_reordered_clusters(sorted_clusters, left_anchor)
  rewrite_cluster_order_map(order_map, reordered_clusters)
}

/// Graphviz parity: root cluster-rank-order phase output keeps root-rank keys
/// and ordered-root groups bundled for rank-transfer dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRankOrderPhaseOutput {
  root_rank_keys : Array[Int]
  ordered_root : Map[Int, Array[String]]
}

fn has_multiple_non_empty_cluster_keys(
  order_cluster_keys : Map[String, String],
) -> Bool {
  let seen_cluster_keys : Map[String, Bool] = Map::new()
  for _name, key in order_cluster_keys {
    if key == "" || seen_cluster_keys.get(key) is Some(_) {
      continue
    }
    seen_cluster_keys[key] = true
    if seen_cluster_keys.length() > 1 {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: root-only graphviz_flip gating enables root flip only when
/// capture-fixture mode is active or when at least two non-empty cluster keys
/// exist in the current ordering key map.
fn should_enable_root_flip(
  graphviz_flip : Bool,
  order_cluster_keys : Map[String, String],
) -> Bool {
  if !graphviz_flip {
    return false
  }
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
    return true
  }
  has_multiple_non_empty_cluster_keys(order_cluster_keys)
}

///|
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_order_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_reorder_output : @ordering.RootClusterReorderInputs,
) -> RootClusterRankOrderPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  // Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
  // path as cluster-phase root bucket ordering, with root-flip guarding.
  let root_graphviz_flip =
    should_enable_root_flip(
      reorder_setup.graphviz_flip,
      pre_root_stage.order_cluster_keys,
    )
  let ordered_root =
    reorder_rank_groups(
      root_reorder_output.root_rank_keys,
      root_reorder_output.root_groups,
      root_reorder_output.root_edges_out,
      root_reorder_output.root_edge_tail_out,
      root_reorder_output.root_edge_head_out,
      root_reorder_output.root_edge_tail_port_x,
      root_reorder_output.root_edge_head_port_x,
      root_reorder_output.root_edge_tail_port_order,
      root_reorder_output.root_edge_head_port_order,
      root_reorder_output.root_parents,
      root_reorder_output.root_children,
      pre_root_stage.order_cluster_keys,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      root_reorder_output.root_edge_order,
      root_reorder_output.root_node_order,
      pre_root_stage.order_sizes_out,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      Map::new(),
      pre_root_stage.order_cluster_skeleton,
      dispatch_context.cluster_meta.flat_constraints,
      graphviz_flip=root_graphviz_flip,
      coalesce_parallel_edges=true,
    )
  finalize_root_rank_order_phase_output(
    root_reorder_output.root_rank_keys,
    root_reorder_output.root_groups,
    ordered_root,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    reorder_setup.graphviz_flip,
  )
}

///|
/// Graphviz parity: graphviz_flip root output merge replays ordered root
/// membership from root mincross back into seeded root rank groups.
fn build_graphviz_flip_merged_root_groups(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let ordered_root_nodes =
    @ordering.build_order_nodes_from_groups(ordered_root, root_rank_keys)
  let ordered_root_mincross_nodes =
    @ordering.build_node_membership_set(ordered_root_nodes)
  @ordering.merge_root_mincross_groups(
    root_rank_keys,
    root_groups,
    ordered_root,
    ordered_root_mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root rank-order output merge keeps non-flip output as-is,
/// and only replays root mincross membership back into seeded groups when
/// graphviz_flip was requested for this pass.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_rank_order_phase_output(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
) -> RootClusterRankOrderPhaseOutput {
  if !graphviz_flip {
    return {
      root_rank_keys,
      ordered_root,
    }
  }
  let merged_ordered_root =
    build_graphviz_flip_merged_root_groups(
      root_rank_keys,
      root_groups,
      ordered_root,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  {
    root_rank_keys,
    ordered_root: merged_ordered_root,
  }
}


///|
/// Graphviz parity: root cluster-reorder source bundle is assembled from the
/// clustered dispatch/pre-root snapshots plus the selected rank groups source.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_sources(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> @ordering.RootReorderBuildSources {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  {
    order_with_vnodes: reorder_setup.order_with_vnodes,
    order_rank_keys: reorder_context.order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    edge_vnodes: runtime_context.vnode_info.edge_vnodes,
    vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
    vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
    nlist_order: class2_data.nlist_order,
    ranks: dispatch_context.ranks,
    skeleton_edge_creation: class2_data.skeleton_edge_creation,
    root_edge_creation: class2_data.root_edge_creation,
    flat_rank_constraints: reorder_setup.flat_rank_constraints,
  }
}


///|
/// Graphviz parity: root mincross rank map records first-seen cluster
/// skeleton buckets and one root-real bucket in rank-sequence order.
fn build_rank_cluster_bucket_order_map(
  names : Array[String],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for name in names {
    if order_cluster_skeleton.get(name) == Some(true) {
      let cluster = @ordering.cluster_key_or_empty(order_cluster_keys, name)
      if cluster != "" && order_map.get(cluster) is None {
        order_map[cluster] = idx
        idx = idx + 1
      }
      continue
    }
    if real_nodes.get(name) is Some(_) {
      let cluster = @ordering.cluster_key_or_empty(order_cluster_keys, name)
      if cluster == "" && order_map.get("") is None {
        order_map[""] = idx
        idx = idx + 1
      }
    }
  }
  order_map
}

///|
/// Graphviz parity: cluster-phase rank-order map records first-seen cluster
/// skeleton buckets (or root bucket) per rank, with root-anchor transfer
/// between adjacent ranks when anchor preconditions match.
fn build_cluster_order_from_root(
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let mut previous_order_map : Map[String, Int]? = None
  for rank in root_rank_keys {
    let names = ordered_root.get(rank).unwrap_or_default()
    let order_map =
      build_rank_cluster_bucket_order_map(
        names,
        order_cluster_keys,
        order_cluster_skeleton,
        real_nodes,
      )
    anchor_root_bucket(
      order_map,
      previous_order_map,
    )
    if order_map.length() > 0 {
      cluster_rank_order[rank] = order_map
      previous_order_map = Some(order_map)
    }
  }
  cluster_rank_order
}

///|
/// Graphviz parity: root cluster-reorder phase keeps root input assembly and
/// root rank-order execution in one sequence for shared clustered consumers.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_and_rank_order_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (@ordering.RootClusterReorderInputs, RootClusterRankOrderPhaseOutput) {
  let root_reorder_sources =
    build_root_reorder_sources(
      dispatch_context,
      pre_root_stage,
      order_groups_for_mincross,
    )
  let root_reorder_output =
    @ordering.build_root_reorder_inputs(
      root_reorder_sources,
      dispatch_context.class2_data.order_edges_by_tail_root,
    )
  let root_rank_order_phase_output =
    run_root_rank_order_phase(
      dispatch_context,
      pre_root_stage,
      root_reorder_output,
    )
  (root_reorder_output, root_rank_order_phase_output)
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : OrderRootClusterData,
) -> Map[Int, Map[String, Int]] {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  if !reorder_setup.order_with_clusters {
    return Map::new()
  }
  let (_root_reorder_output, root_rank_order_phase_output) =
    run_root_reorder_and_rank_order_phase(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage.order_groups_for_mincross,
    )
  build_cluster_order_from_root(
    root_rank_order_phase_output.root_rank_keys,
    root_rank_order_phase_output.ordered_root,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    runtime_context.real_nodes,
  )
}

///|
/// Graphviz parity: final rank groups drop non-real nodes after root ordering,
/// preserving rank iteration order and per-rank sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_real_only_rank_groups(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = ordered.get(rank).unwrap_or_default()
    let cleaned : Array[String] = []
    for name in names {
      if real_nodes.get(name) is Some(_) {
        cleaned.push(name)
      }
    }
    if cleaned.length() > 0 {
      cleaned_groups[rank] = cleaned
    }
  }
  cleaned_groups
}

///|
/// Graphviz parity: rank-level override reorders only names present in the
/// current rank while preserving the relative order of unmatched names.
/// Do not change behavior without updating fixtures/tests.
fn reorder_names_by_override(
  names : Array[String],
  override_names : Array[String],
) -> Array[String] {
  let present : Map[String, Bool] = Map::new()
  for name in names {
    present[name] = true
  }
  let reordered : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in override_names {
    if present.get(name) is Some(_) && seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  for name in names {
    if seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  reordered
}

///|
/// Graphviz parity: root-override graphviz_flip replay keeps skeleton names in
/// rank order, reattaches same-cluster names after skeletons, and preserves any
/// unmatched names as final fallback in original rank order.
fn rebuild_root_override_names(
  rank_names : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  // Graphviz parity: root-override skeleton checks treat non-skeleton names as
  // empty cluster keys when rebuilding attached-cluster bundles.
  let skeleton_cluster_or_empty = (name : String) =>
    cluster_key_from_skeleton(name).unwrap_or_default()
  // Graphviz parity: any parsed skeleton cluster key is a skeleton marker.
  let is_root_override_skeleton_name = (name : String) =>
    skeleton_cluster_or_empty(name) != ""
  let skeleton_for_cluster =
    @ordering.build_skeleton_for_clusters(
      rank_names,
      skeleton_cluster_or_empty,
    )
  let attached_by_skeleton =
    @ordering.build_attached_by_skeleton(
      rank_names,
      cluster_keys,
      skeleton_for_cluster,
      is_root_override_skeleton_name,
    )
  let next_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in rank_names {
    if seen.get(name) is Some(_) {
      continue
    }
    let is_skeleton = is_root_override_skeleton_name(name)
    if is_skeleton {
      next_names.push(name)
      seen[name] = true
      @ordering.append_attached_by_skeleton(
        next_names,
        seen,
        attached_by_skeleton,
        name,
      )
      continue
    }
    let cluster = @ordering.cluster_key_or_empty(cluster_keys, name)
    if cluster != "" && skeleton_for_cluster.get(cluster) is Some(_) {
      continue
    }
    next_names.push(name)
    seen[name] = true
  }
  for name in rank_names {
    if seen.get(name) is None {
      next_names.push(name)
      seen[name] = true
    }
  }
  next_names
}

///|
/// Graphviz parity: rank-level root override first applies explicit override
/// order, then replays cluster-attached skeleton ordering only in flip mode.
/// Do not change behavior without updating fixtures/tests.
fn build_root_override_rank_names(
  names : Array[String],
  override_names : Array[String],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Array[String] {
  let rank_names =
    reorder_names_by_override(
      names,
      override_names,
    )
  if !graphviz_flip {
    return rank_names
  }
  rebuild_root_override_names(rank_names, cluster_keys)
}

///|
/// Graphviz parity: root phase can apply a rank-order override from root
/// mincross output before local cluster passes.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_groups_override(
  groups : Map[Int, Array[String]],
  override_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reordered = @ordering.clone_rank_groups(groups)
  for rank, override_names in override_groups {
    match reordered.get(rank) {
      Some(names) =>
        reordered[rank] =
          build_root_override_rank_names(
            names,
            override_names,
            cluster_keys,
            graphviz_flip,
          )
      None => ()
    }
  }
  reordered
}

///|
/// Graphviz parity: clustered-block bounds are the first/last clustered-name
/// positions in the rank, with (-1, -1) when no clustered names exist.
priv struct ClusterBlockBounds {
  first_cluster : Int
  last_cluster : Int
}

///|
/// Graphviz parity: clustered-block bounds are the first/last clustered-name
/// positions in the rank, with (-1, -1) when no clustered names exist.
fn find_cluster_block_bounds(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> ClusterBlockBounds {
  let mut first_cluster = -1
  let mut last_cluster = -1
  for i in 0..<names.length() {
    let cluster = @ordering.cluster_key_or_empty(cluster_keys, names[i])
    if cluster != "" {
      if first_cluster < 0 {
        first_cluster = i
      }
      last_cluster = i
    }
  }
  { first_cluster, last_cluster }
}

///|
/// Graphviz parity: root/non-cluster presence checks on one side of clustered
/// blocks scan rank names in-order and stop at first root bucket member.
fn has_root_node_in_range(
  names : Array[String],
  cluster_keys : Map[String, String],
  start_idx : Int,
  end_idx : Int,
) -> Bool {
  let mut i = start_idx
  while i < end_idx {
    if @ordering.cluster_key_or_empty(cluster_keys, names[i]) == "" {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Graphviz parity: cluster-rank-order guard keeps original rank order when
/// root nodes appear on both sides of the clustered node block in one rank.
fn has_root_nodes_on_both_sides(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> Bool {
  if names.length() <= 2 {
    return false
  }
  let cluster_block_bounds =
    find_cluster_block_bounds(names, cluster_keys)
  let first_cluster = cluster_block_bounds.first_cluster
  if first_cluster < 0 {
    return false
  }
  let root_before =
    has_root_node_in_range(
      names,
      cluster_keys,
      0,
      first_cluster,
    )
  let root_after =
    if cluster_block_bounds.last_cluster + 1 >= names.length() {
      false
    } else {
      has_root_node_in_range(
        names,
        cluster_keys,
        cluster_block_bounds.last_cluster + 1,
        names.length(),
      )
    }
  root_before && root_after
}

///|
priv struct ClusterOrderBucket {
  order : Int
  seq_idx : Int
  cluster : String
}

///|
/// Graphviz parity: cluster bucket grouping keeps first-seen cluster sequence,
/// orders buckets by root rank-order map, and preserves intra-bucket order.
/// Do not change behavior without updating fixtures/tests.
fn order_rank_names_by_cluster_buckets(
  names : Array[String],
  order_map : Map[String, Int],
  cluster_keys : Map[String, String],
) -> Array[String] {
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_seq : Array[String] = []
  for name in names {
    let cluster = @ordering.cluster_key_or_empty(cluster_keys, name)
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => {
        cluster_nodes[cluster] = [name]
        cluster_seq.push(cluster)
      }
    }
  }
  let cluster_ordered : Array[ClusterOrderBucket] = []
  for idx, cluster in cluster_seq {
    let base = order_map.get(cluster).unwrap_or(order_map.length() + idx)
    cluster_ordered.push({ order: base, seq_idx: idx, cluster })
  }
  if cluster_ordered.length() > 1 {
    cluster_ordered.sort_by((a, b) => {
      if a.order < b.order {
        -1
      } else if a.order > b.order {
        1
      } else if a.seq_idx < b.seq_idx {
        -1
      } else if a.seq_idx > b.seq_idx {
        1
      } else {
        0
      }
    })
  }
  let ordered_names : Array[String] = []
  for entry in cluster_ordered {
    let nodes_in_cluster = cluster_nodes.get(entry.cluster).unwrap_or_default()
    for name in nodes_in_cluster {
      ordered_names.push(name)
    }
  }
  ordered_names
}

///|
/// Graphviz parity: per-rank cluster replay applies root rank-order only when
/// an order map exists and root nodes do not straddle clustered block bounds.
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_group_by_cluster_order(
  names : Array[String],
  order_map : Map[String, Int]?,
  cluster_keys : Map[String, String],
) -> Array[String] {
  match order_map {
    None => names
    Some(value) => {
      // Graphviz parity: per-rank cluster-rank-order replay preserves original
      // rank order when root nodes straddle clustered block.
      if has_root_nodes_on_both_sides(names, cluster_keys) {
        names
      } else {
        order_rank_names_by_cluster_buckets(
          names,
          value,
          cluster_keys,
        )
      }
    }
  }
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_groups_by_cluster(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let ordered_by_cluster : Map[Int, Array[String]] = Map::new()
  for rank, names in final_groups {
    ordered_by_cluster[rank] =
      reorder_rank_group_by_cluster_order(
        names,
        cluster_rank_order.get(rank),
        cluster_keys,
      )
  }
  ordered_by_cluster
}
