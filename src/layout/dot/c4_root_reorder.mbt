///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.

///|
/// Graphviz parity: membership checks for mincross subgraph are exact-name set
/// lookups over the filtered node list.
/// Do not change behavior without updating fixtures/tests.
fn build_node_membership_set(names : Array[String]) -> Map[String, Bool] {
  let membership : Map[String, Bool] = Map::new()
  for name in names {
    membership[name] = true
  }
  membership
}

///|
priv struct SyntheticPortValues {
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
/// Graphviz parity: synthetic mincross endpoints keep default port values at
/// zero when Graphviz treats the endpoint pair as synthetic-only.
fn normalize_synthetic_ports(
  tail : String,
  head : String,
  tail_port_x_raw : Double,
  head_port_x_raw : Double,
  tail_port_order_raw : Double,
  head_port_order_raw : Double,
) -> SyntheticPortValues {
  // Graphviz parity: synthetic ordering nodes keep default mincross ports
  // unless a non-default port survives edge materialization.
  let tail_is_skeleton = tail.has_prefix(CLUSTER_SKELETON_PREFIX)
  let head_is_skeleton = head.has_prefix(CLUSTER_SKELETON_PREFIX)
  let synthetic_endpoint =
    is_edge_vnode_name(tail) || is_edge_vnode_name(head) ||
    tail_is_skeleton || head_is_skeleton
  let defaultish_x =
    (tail_port_x_raw == 0.0 || tail_port_x_raw == 0.5) &&
    (head_port_x_raw == 0.0 || head_port_x_raw == 0.5)
  let zero_synthetic_defaults =
    synthetic_endpoint &&
    (
      (tail_is_skeleton && head_is_skeleton) ||
      (defaultish_x && tail_port_order_raw == 0.0 && head_port_order_raw == 0.0)
    )
  if !zero_synthetic_defaults {
    return {
      tail_port_x: tail_port_x_raw,
      head_port_x: head_port_x_raw,
      tail_port_order: tail_port_order_raw,
      head_port_order: head_port_order_raw,
    }
  }
  {
    tail_port_x: 0.0,
    head_port_x: 0.0,
    tail_port_order: 0.0,
    head_port_order: 0.0,
  }
}

///|
priv struct MincrossOrderEdgesOutput {
  order_edges_out_mincross : Array[@cgraph.Edge]
  order_edge_tail_out_mincross : Array[String]
  order_edge_head_out_mincross : Array[String]
  order_edge_tail_port_x_mincross : Array[Double]
  order_edge_head_port_x_mincross : Array[Double]
  order_edge_tail_port_order_mincross : Array[Double]
  order_edge_head_port_order_mincross : Array[Double]
}

///|
/// Graphviz parity: root mincross edge set keeps only edges whose endpoints are
/// both in the filtered node set, preserving edge and port-order sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_mincross_order_edges(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> MincrossOrderEdgesOutput {
  let order_edges_out_mincross : Array[@cgraph.Edge] = []
  let order_edge_tail_out_mincross : Array[String] = []
  let order_edge_head_out_mincross : Array[String] = []
  let order_edge_tail_port_x_mincross : Array[Double] = []
  let order_edge_head_port_x_mincross : Array[Double] = []
  let order_edge_tail_port_order_mincross : Array[Double] = []
  let order_edge_head_port_order_mincross : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < order_edges_out.length() {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    if mincross_nodes.get(tail) is Some(_) && mincross_nodes.get(head) is Some(_) {
      let tail_port_x_raw = order_edge_tail_port_x[edge_idx]
      let head_port_x_raw = order_edge_head_port_x[edge_idx]
      let tail_port_order_raw = order_edge_tail_port_order[edge_idx]
      let head_port_order_raw = order_edge_head_port_order[edge_idx]
      let normalized_ports =
        normalize_synthetic_ports(
          tail,
          head,
          tail_port_x_raw,
          head_port_x_raw,
          tail_port_order_raw,
          head_port_order_raw,
        )
      order_edges_out_mincross.push(order_edges_out[edge_idx])
      order_edge_tail_out_mincross.push(tail)
      order_edge_head_out_mincross.push(head)
      order_edge_tail_port_x_mincross.push(normalized_ports.tail_port_x)
      order_edge_head_port_x_mincross.push(normalized_ports.head_port_x)
      order_edge_tail_port_order_mincross.push(normalized_ports.tail_port_order)
      order_edge_head_port_order_mincross.push(normalized_ports.head_port_order)
    }
    edge_idx = edge_idx + 1
  }
  {
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  }
}

///|
/// Graphviz parity: after root-only mincross, reordered root/skeleton nodes are
/// merged back into seeded rank lists by replacing only filtered positions.
/// Do not change behavior without updating fixtures/tests.
fn merge_root_mincross_groups(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = seeded_groups.get(rank).unwrap_or_default().copy()
    let replacements = ordered_mincross.get(rank).unwrap_or_default()
    if replacements.length() == 0 {
      merged[rank] = names
      continue
    }
    // Graphviz parity: keep cluster-internal nodes attached to the rankleader
    // skeleton position when root mincross reorders cluster skeleton chains.
    let skeleton_for_cluster =
      build_skeleton_for_clusters(
        names,
        (name) =>
          if order_cluster_skeleton.get(name) == Some(true) {
            cluster_key_or_empty(order_cluster_keys, name)
          } else {
            ""
          },
      )
    let attached_by_skeleton =
      build_attached_by_skeleton(
        names,
        order_cluster_keys,
        skeleton_for_cluster,
        (name) => mincross_nodes.get(name) is Some(_),
      )
    // Graphviz parity: when root mincross returns [root, skeleton] in a
    // single-root rank, keep the attached cluster node in front via positional
    // replacement (matches biological rank handoff in Graphviz).
    let should_use_positional_merge =
      should_merge_root_positions(
        replacements,
        order_cluster_skeleton,
        attached_by_skeleton,
      )
    if should_use_positional_merge {
      let mut replace_idx = 0
      for i in 0..<names.length() {
        if mincross_nodes.get(names[i]) is Some(_) {
          if replace_idx < replacements.length() {
            names[i] = replacements[replace_idx]
            replace_idx = replace_idx + 1
          }
        }
      }
      merged[rank] = names
      continue
    }
    let next_names : Array[String] = []
    let seen : Map[String, Bool] = Map::new()
    for replacement in replacements {
      next_names.push(replacement)
      seen[replacement] = true
      if order_cluster_skeleton.get(replacement) == Some(true) {
        append_attached_by_skeleton(
          next_names,
          seen,
          attached_by_skeleton,
          replacement,
        )
      }
    }
    for name in names {
      if seen.get(name) is None {
        next_names.push(name)
        seen[name] = true
      }
    }
    merged[rank] = next_names
  }
  merged
}

///|
/// Graphviz parity: cluster->skeleton map keeps last-seen skeleton per cluster
/// from input order and ignores names without a cluster skeleton key.
fn build_skeleton_for_clusters(
  names : Array[String],
  cluster_for_name : (String) -> String,
) -> Map[String, String] {
  let skeleton_for_cluster : Map[String, String] = Map::new()
  for name in names {
    let cluster = cluster_for_name(name)
    if cluster != "" {
      skeleton_for_cluster[cluster] = name
    }
  }
  skeleton_for_cluster
}

///|
/// Graphviz parity: attached-by-skeleton buckets map non-skipped cluster
/// members to their rankleader skeleton in input order.
fn build_attached_by_skeleton(
  names : Array[String],
  cluster_keys : Map[String, String],
  skeleton_for_cluster : Map[String, String],
  should_skip : (String) -> Bool,
) -> Map[String, Array[String]] {
  let attached_by_skeleton : Map[String, Array[String]] = Map::new()
  for name in names {
    if should_skip(name) {
      continue
    }
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    match skeleton_for_cluster.get(cluster) {
      Some(skeleton_name) =>
        match attached_by_skeleton.get(skeleton_name) {
          Some(list) => list.push(name)
          None => attached_by_skeleton[skeleton_name] = [name]
        }
      None => ()
    }
  }
  attached_by_skeleton
}

///|
/// Graphviz parity: attached cluster members are replayed after their
/// skeleton only once, preserving original attached list order.
fn append_attached_by_skeleton(
  target : Array[String],
  seen : Map[String, Bool],
  attached_by_skeleton : Map[String, Array[String]],
  skeleton_name : String,
) -> Unit {
  let attached = attached_by_skeleton.get(skeleton_name).unwrap_or_default()
  for attached_name in attached {
    if seen.get(attached_name) is None {
      target.push(attached_name)
      seen[attached_name] = true
    }
  }
}

///|
/// Graphviz parity: positional root merge triggers only for [root, skeleton]
/// replacement pairs with exactly one attached member on that skeleton.
fn should_merge_root_positions(
  replacements : Array[String],
  order_cluster_skeleton : Map[String, Bool],
  attached_by_skeleton : Map[String, Array[String]],
) -> Bool {
  if replacements.length() != 2 {
    return false
  }
  if order_cluster_skeleton.get(replacements[1]) != Some(true) ||
    order_cluster_skeleton.get(replacements[0]) == Some(true) {
    return false
  }
  let attached_count =
    attached_by_skeleton.get(replacements[1]).unwrap_or_default().length()
  attached_count == 1
}

///|
/// Graphviz parity: root cluster reorder GD_nlist keeps skeleton/root tail
/// sequence from input order, prioritizes source tails, then rebuilds nlist via
/// edge creation order while appending any missing root nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_order(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> Array[String] {
  // Graphviz parity: root cluster reorder seeds tail order from current nlist,
  // replacing cluster members with rank-qualified skeleton names and deduping.
  let tail_order_root : Array[String] = []
  let tail_root_seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster != "" {
      let rank = flat_constraint_rank_or_zero(ranks, name)
      let skel = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      append_creation_name(
        tail_order_root,
        tail_root_seen,
        skel,
      )
    } else {
      append_creation_name(
        tail_order_root,
        tail_root_seen,
        name,
      )
    }
  }
  let root_edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      root_edge_creation,
    )
  // Graphviz parity: root source-first ordering marks incoming heads among
  // root nodes from merged edge-creation order before tail-order filtering.
  let root_has_in : Map[String, Bool] = Map::new()
  for name in root_nodes {
    root_has_in[name] = false
  }
  for edge in root_edge_creation_order {
    let (_tail, head) = edge
    if root_has_in.get(head) is Some(_) {
      root_has_in[head] = true
    }
  }
  // Graphviz parity: root tail visit order places source tails (no incoming
  // edges) first while preserving original deduped tail sequence order.
  let root_tail_order : Array[String] = []
  let root_tail_seen : Map[String, Bool] = Map::new()
  for name in tail_order_root {
    if root_has_in.get(name) == Some(false) {
      append_creation_name(
        root_tail_order,
        root_tail_seen,
        name,
      )
    }
  }
  for name in tail_order_root {
    append_creation_name(
      root_tail_order,
      root_tail_seen,
      name,
    )
  }
  let root_nlist_full =
    @dot_shared.build_graphviz_nlist_order_from_edges(
      root_tail_order,
      root_nodes,
      root_edge_creation_order,
      flat_rank_constraints,
    )
  // Graphviz parity: root GD_nlist output keeps only materialized root nodes,
  // then appends any missing root names in root_nodes order.
  let root_nlist_order : Array[String] = []
  let root_seen : Map[String, Bool] = Map::new()
  for name in root_nlist_full {
    if root_node_map.get(name) is Some(_) {
      root_seen[name] = true
      root_nlist_order.push(name)
    }
  }
  if root_nlist_order.length() < root_nodes.length() {
    for name in root_nodes {
      if root_seen.get(name) is None {
        root_nlist_order.push(name)
      }
    }
  }
  root_nlist_order
}

///|
/// Graphviz parity: root cluster reorder edge endpoint reads prefer oriented
/// edge_tail/edge_head arrays and fall back to edge object endpoints.
priv struct RootEdgeEndpoints {
  tail : String
  head : String
}

///|
/// Graphviz parity: root cluster reorder edge endpoint reads prefer oriented
/// edge_tail/edge_head arrays and fall back to edge object endpoints.
fn root_edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> RootEdgeEndpoints {
  let tail =
    if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
      edge.tail().name()
    }
  let head =
    if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
      edge.head().name()
    }
  { tail, head }
}

///|
/// Graphviz parity: root-vnode set for root cluster reorder includes only
/// edge-vnodes on edges crossing cluster boundaries.
fn collect_root_vnodes(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let root_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return root_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let endpoints =
      root_edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
    let tail = endpoints.tail
    let head = endpoints.head
    let tail_cluster = cluster_key_or_empty(cluster_keys, tail)
    let head_cluster = cluster_key_or_empty(cluster_keys, head)
    if tail_cluster != head_cluster {
      let vnodes = edge_vnodes.get(@dot_shared.edge_vnode_key(edge)).unwrap_or_default()
      for vnode in vnodes {
        root_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  root_vnodes
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode-order key map.
priv struct RootVnodeInputs {
  root_vnodes_by_rank : Map[Int, Array[String]]
  root_vnode_order_keys : Map[String, Double]
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode-order key map.
fn build_root_vnode_inputs(
  order_with_vnodes : Bool,
  root_vnodes : Map[String, Bool],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> RootVnodeInputs {
  let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let root_vnode_order_keys : Map[String, Double] = Map::new()
  if !order_with_vnodes {
    return { root_vnodes_by_rank, root_vnode_order_keys }
  }
  for rank, names in vnodes_by_rank {
    let filtered : Array[String] = []
    for name in names {
      if root_vnodes.get(name) == Some(true) {
        filtered.push(name)
      }
    }
    if filtered.length() > 0 {
      root_vnodes_by_rank[rank] = filtered
    }
  }
  for name, key in vnode_order_keys_for_ordering {
    if root_vnodes.get(name) == Some(true) {
      root_vnode_order_keys[name] = key
    }
  }
  { root_vnodes_by_rank, root_vnode_order_keys }
}

///|
/// Graphviz parity: root cluster reorder groups keep root/skeleton base order
/// and optionally merge only root-vnodes into rank groups using filtered vnode
/// keys/rank buckets from root-mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_groups(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[Int, Array[String]] {
  let root_vnodes =
    collect_root_vnodes(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
    )
  // Graphviz parity: root cluster reorder base groups keep only root/skeleton
  // nodes, and include edge-vnodes only when flagged as root-vnodes.
  let root_groups_base : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = order_groups_for_mincross.get(rank).unwrap_or_default()
    let root_names : Array[String] = []
    for name in names {
      // Graphviz parity: root reorder rank filtering keeps root-cluster
      // skeletons plus root real nodes, and only keeps edge-vnodes when
      // marked as root-vnodes.
      let cluster = cluster_key_or_empty(order_cluster_keys, name)
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      if !is_skeleton && cluster != "" {
        continue
      }
      if name.has_prefix(EDGE_VNODE_PREFIX) && root_vnodes.get(name) != Some(true) {
        continue
      }
      root_names.push(name)
    }
    if root_names.length() > 0 {
      root_groups_base[rank] = root_names
    }
  }
  let root_order_index = build_order_index(root_groups_base)
  let root_vnode_inputs =
    build_root_vnode_inputs(
      order_with_vnodes,
      root_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      root_groups_base,
      root_order_index,
      root_vnode_inputs.root_vnodes_by_rank,
      root_vnode_inputs.root_vnode_order_keys,
    )
  } else {
    root_groups_base
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
  let prev_map = match previous_order_map {
    Some(value) => value
    None => return ()
  }
  let prev_root = match prev_map.get("") {
    Some(value) => value
    None => return ()
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
    return ()
  }
  let left = match left_anchor {
    Some(value) => value
    None => return ()
  }
  // Graphviz parity: cluster-rank sort keys are normalized into deterministic
  // non-root order by (order, cluster-name) before root-anchor transfer.
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
  if sorted_clusters.length() == 0 {
    return ()
  }
  // Graphviz parity: root-anchor transfer inserts root bucket immediately
  // after the selected left-anchor cluster in sorted non-root order.
  let mut insert_idx = sorted_clusters.length()
  for i in 0..<sorted_clusters.length() {
    if sorted_clusters[i] == left {
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
  let mut idx = 0
  for cluster in reordered {
    order_map[cluster] = idx
    idx = idx + 1
  }
}

/// Graphviz parity: root cluster-rank-order phase output keeps root-rank keys
/// and ordered-root groups bundled for rank-transfer dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRankOrderPhaseOutput {
  root_rank_keys : Array[Int]
  ordered_root : Map[Int, Array[String]]
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
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_order_phase(
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  root_reorder_output : RootClusterReorderInputs,
) -> RootClusterRankOrderPhaseOutput {
  // Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
  // path as cluster-phase root bucket ordering, with root-flip guarding.
  let root_graphviz_flip =
    should_enable_root_flip(graphviz_flip, order_cluster_keys)
  let ordered_root = reorder_rank_groups(
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
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    root_reorder_output.root_edge_order,
    root_reorder_output.root_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=true,
  )
  if !graphviz_flip {
    return {
      root_rank_keys: root_reorder_output.root_rank_keys,
      ordered_root,
    }
  }
  // Graphviz parity: root graphviz_flip merge replays root mincross output
  // back into seeded rank groups using filtered root node membership.
  let ordered_root_nodes =
    build_order_nodes_from_groups(ordered_root, root_reorder_output.root_rank_keys)
  let ordered_root_mincross_nodes =
    build_node_membership_set(ordered_root_nodes)
  let merged_ordered_root =
    merge_root_mincross_groups(
      root_reorder_output.root_rank_keys,
      root_reorder_output.root_groups,
      ordered_root,
      ordered_root_mincross_nodes,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  {
    root_rank_keys: root_reorder_output.root_rank_keys,
    ordered_root: merged_ordered_root,
  }
}


///|
/// Graphviz parity: root cluster-rank-order prep payload keeps root
/// groups/edges/node-order values unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterReorderInputs {
  root_groups : Map[Int, Array[String]]
  root_rank_keys : Array[Int]
  root_edges_out : Array[@cgraph.Edge]
  root_edge_tail_out : Array[String]
  root_edge_head_out : Array[String]
  root_edge_tail_port_x : Array[Double]
  root_edge_head_port_x : Array[Double]
  root_edge_tail_port_order : Array[Double]
  root_edge_head_port_order : Array[Double]
  root_parents : Map[String, Array[String]]
  root_children : Map[String, Array[String]]
  root_edge_order : Map[String, Int]
  root_node_order : Map[String, Int]
}

///|
/// Graphviz parity: root reorder context keeps root groups, ranks, graph
/// handles, GD_nlist walk order, and seeded node-order map before root-only
/// edge materialization.
priv struct RootClusterReorderContext {
  root_groups : Map[Int, Array[String]]
  root_rank_keys : Array[Int]
  root_ranks : Map[String, Int]
  root_nodes : Array[String]
  root_graph : @cgraph.Graph
  root_node_map : Map[String, @cgraph.Node]
  root_nlist_order : Array[String]
  root_node_order : Map[String, Int]
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// first, then fills missing names from current rank-group order index.
fn build_root_reorder_node_order(
  root_nlist_order : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  root_groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let root_node_order : Map[String, Int] = Map::new()
  let mut root_node_idx = 0
  for name in root_nlist_order {
    if root_node_map.get(name) is Some(_) {
      root_node_order[name] = root_node_idx
      root_node_idx = root_node_idx + 1
    }
  }
  let root_order_index = build_order_index(root_groups)
  for name, idx in root_order_index {
    if root_node_order.get(name) is None {
      root_node_order[name] = idx
    }
  }
  root_node_order
}

///|
/// Graphviz parity: root edge-port arrays are normalized with synthetic-endpoint
/// defaults before root mincross edge-index construction.
priv struct NormalizedRootEdgePorts {
  edge_tail_port_x_norm : Array[Double]
  edge_head_port_x_norm : Array[Double]
  edge_tail_port_order_norm : Array[Double]
  edge_head_port_order_norm : Array[Double]
}

///|
/// Graphviz parity: root edge-port arrays are normalized with synthetic-endpoint
/// defaults before root mincross edge-index construction.
fn normalize_root_edge_ports(
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> NormalizedRootEdgePorts {
  let edge_tail_port_x_norm : Array[Double] = []
  let edge_head_port_x_norm : Array[Double] = []
  let edge_tail_port_order_norm : Array[Double] = []
  let edge_head_port_order_norm : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < edge_tail_out.length() {
    let tail = edge_tail_out[edge_idx]
    let head = edge_head_out[edge_idx]
    let tail_port_x_raw = edge_tail_port_x[edge_idx]
    let head_port_x_raw = edge_head_port_x[edge_idx]
    let tail_port_order_raw = edge_tail_port_order[edge_idx]
    let head_port_order_raw = edge_head_port_order[edge_idx]
    let normalized_ports =
      normalize_synthetic_ports(
        tail,
        head,
        tail_port_x_raw,
        head_port_x_raw,
        tail_port_order_raw,
        head_port_order_raw,
      )
    edge_tail_port_x_norm.push(normalized_ports.tail_port_x)
    edge_head_port_x_norm.push(normalized_ports.head_port_x)
    edge_tail_port_order_norm.push(normalized_ports.tail_port_order)
    edge_head_port_order_norm.push(normalized_ports.head_port_order)
    edge_idx = edge_idx + 1
  }
  {
    edge_tail_port_x_norm,
    edge_head_port_x_norm,
    edge_tail_port_order_norm,
    edge_head_port_order_norm,
  }
}

///|
/// Graphviz parity: root reorder context is built from root-only filtered rank
/// groups and shared GD_nlist walk order before root mincross edge bundle.
fn build_root_reorder_context(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> RootClusterReorderContext {
  let root_groups =
    build_root_reorder_groups(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  let root_rank_keys = collect_rank_keys(root_groups)
  let root_ranks = build_node_ranks(root_groups)
  let root_nodes = build_order_nodes_from_groups(root_groups, root_rank_keys)
  let root_graph_output =
    build_order_graph_and_nodes("order_root", root_nodes)
  let root_graph = root_graph_output.order_graph
  let root_node_map = root_graph_output.order_node_map
  // Graphviz parity: root cluster-reorder derives root GD_nlist walk order and
  // root-node order map from the same root graph/group membership snapshot.
  let root_nlist_order =
    build_root_nlist_order(
      nlist_order,
      cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  let root_node_order =
    build_root_reorder_node_order(
      root_nlist_order,
      root_node_map,
      root_groups,
    )
  {
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  }
}

///|
/// Graphviz parity: root reorder context + root edge bundle are materialized
/// before root-only mincross in cluster-order phase.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_inputs(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootClusterReorderInputs {
  let root_context =
    build_root_reorder_context(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
      nlist_order,
      ranks,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  // Graphviz parity: root reorder edge bundle keeps tail-sequence
  // materialized edges, synthetic port normalization, and edge index/order
  // maps in one stage.
  let root_materialized =
    collect_order_edges_for_tails(
      root_context.root_nlist_order,
      order_edges_by_tail_root,
      root_context.root_graph,
      root_context.root_node_map,
    )
  let normalized_root_ports =
    normalize_root_edge_ports(
      root_materialized.order_edge_tail_out,
      root_materialized.order_edge_head_out,
      root_materialized.order_edge_tail_port_x,
      root_materialized.order_edge_head_port_x,
      root_materialized.order_edge_tail_port_order,
      root_materialized.order_edge_head_port_order,
    )
  let root_edge_indices =
    build_edge_indices_and_order(
      root_context.root_nodes,
      root_materialized.order_edge_tail_out,
      root_materialized.order_edge_head_out,
      root_context.root_ranks,
      root_materialized.order_edges_out,
    )
  {
    root_groups: root_context.root_groups,
    root_rank_keys: root_context.root_rank_keys,
    root_edges_out: root_materialized.order_edges_out,
    root_edge_tail_out: root_materialized.order_edge_tail_out,
    root_edge_head_out: root_materialized.order_edge_head_out,
    root_edge_tail_port_x: normalized_root_ports.edge_tail_port_x_norm,
    root_edge_head_port_x: normalized_root_ports.edge_head_port_x_norm,
    root_edge_tail_port_order: normalized_root_ports.edge_tail_port_order_norm,
    root_edge_head_port_order: normalized_root_ports.edge_head_port_order_norm,
    root_parents: root_edge_indices.parents,
    root_children: root_edge_indices.children,
    root_edge_order: root_edge_indices.edge_order,
    root_node_order: root_context.root_node_order,
  }
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
    // Graphviz parity: root mincross rank map records first-seen cluster
    // skeleton buckets and one root-real bucket in rank-sequence order.
    let order_map : Map[String, Int] = Map::new()
    let mut idx = 0
    for name in names {
      if order_cluster_skeleton.get(name) == Some(true) {
        let cluster = cluster_key_or_empty(order_cluster_keys, name)
        if cluster != "" && order_map.get(cluster) is None {
          order_map[cluster] = idx
          idx = idx + 1
        }
      } else if real_nodes.get(name) is Some(_) {
        let cluster = cluster_key_or_empty(order_cluster_keys, name)
        if cluster == "" && order_map.get("") is None {
          order_map[""] = idx
          idx = idx + 1
        }
      }
    }
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
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  if !order_with_clusters {
    return Map::new()
  }
  let root_reorder_output =
    build_root_reorder_inputs(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_meta.cluster_keys,
      vnode_info.edge_vnodes,
      vnode_info.vnodes_by_rank,
      vnode_order_keys_for_ordering,
      nlist_order,
      ranks,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
      order_edges_by_tail_root,
    )
  let root_rank_order_phase_output =
    run_root_rank_order_phase(
      order_cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      order_cluster_skeleton,
      cluster_meta.flat_constraints,
      graphviz_flip,
      root_reorder_output,
    )
  build_cluster_order_from_root(
    root_rank_order_phase_output.root_rank_keys,
    root_rank_order_phase_output.ordered_root,
    order_cluster_keys,
    order_cluster_skeleton,
    real_nodes,
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
    build_skeleton_for_clusters(
      rank_names,
      skeleton_cluster_or_empty,
    )
  let attached_by_skeleton =
    build_attached_by_skeleton(
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
      append_attached_by_skeleton(
        next_names,
        seen,
        attached_by_skeleton,
        name,
      )
      continue
    }
    let cluster = cluster_key_or_empty(cluster_keys, name)
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
/// Graphviz parity: root phase can apply a rank-order override from root
/// mincross output before local cluster passes.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_groups_override(
  groups : Map[Int, Array[String]],
  override_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reordered = clone_rank_groups(groups)
  for rank, override_names in override_groups {
    match reordered.get(rank) {
      Some(names) => {
        let rank_names =
          reorder_names_by_override(
            names,
            override_names,
          )
        if !graphviz_flip {
          reordered[rank] = rank_names
          continue
        }
        let next_names =
          rebuild_root_override_names(
            rank_names,
            cluster_keys,
          )
        reordered[rank] = next_names
      }
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
    let cluster = cluster_key_or_empty(cluster_keys, names[i])
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
  let mut root_before = false
  for i in 0..<first_cluster {
    if cluster_key_or_empty(cluster_keys, names[i]) == "" {
      root_before = true
      break
    }
  }
  let root_after =
    if cluster_block_bounds.last_cluster + 1 < names.length() {
      let mut found = false
      for i in (cluster_block_bounds.last_cluster + 1)..<names.length() {
        if cluster_key_or_empty(cluster_keys, names[i]) == "" {
          found = true
          break
        }
      }
      found
    } else {
      false
    }
  root_before && root_after
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
    let order_map = match cluster_rank_order.get(rank) {
      Some(value) => value
      None => {
        ordered_by_cluster[rank] = names
        continue
      }
    }
    // Graphviz parity: per-rank cluster-rank-order replay preserves original
    // rank order when root nodes straddle clustered block.
    if has_root_nodes_on_both_sides(names, cluster_keys) {
      ordered_by_cluster[rank] = names
      continue
    }
    // Graphviz parity: cluster bucket grouping keeps first-seen cluster
    // sequence while preserving per-cluster name order inside each rank.
    let cluster_nodes : Map[String, Array[String]] = Map::new()
    let cluster_seq : Array[String] = []
    for name in names {
      let cluster = cluster_key_or_empty(cluster_keys, name)
      match cluster_nodes.get(cluster) {
        Some(list) => list.push(name)
        None => {
          cluster_nodes[cluster] = [name]
          cluster_seq.push(cluster)
        }
      }
    }
    // Graphviz parity: cluster bucket sort keys use root rank-order map with
    // stable first-seen sequence fallback for missing clusters.
    let cluster_ordered : Array[(Int, Int, String)] = []
    for idx, cluster in cluster_seq {
      let base = order_map.get(cluster).unwrap_or(order_map.length() + idx)
      cluster_ordered.push((base, idx, cluster))
    }
    if cluster_ordered.length() > 1 {
      cluster_ordered.sort_by((a, b) => {
        let (a_order, a_idx, _a_name) = a
        let (b_order, b_idx, _b_name) = b
        if a_order < b_order {
          -1
        } else if a_order > b_order {
          1
        } else if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      })
    }
    // Graphviz parity: bucket flattening emits clusters in sorted order while
    // preserving each cluster's original node sequence.
    let ordered_names : Array[String] = []
    for entry in cluster_ordered {
      let (_order, _idx, cluster) = entry
      let nodes_in_cluster = cluster_nodes.get(cluster).unwrap_or_default()
      for name in nodes_in_cluster {
        ordered_names.push(name)
      }
    }
    ordered_by_cluster[rank] = ordered_names
  }
  ordered_by_cluster
}
