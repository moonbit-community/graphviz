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
/// Graphviz parity: mincross port metadata on synthetic ordering nodes uses
/// default zero offsets/order unless an explicit non-default port survives
/// into the materialized order edge.
/// Do not change behavior without updating fixtures/tests.
fn should_zero_synthetic_mincross_ports(
  tail : String,
  head : String,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
) -> Bool {
  let tail_is_skeleton = tail.has_prefix(CLUSTER_SKELETON_PREFIX)
  let head_is_skeleton = head.has_prefix(CLUSTER_SKELETON_PREFIX)
  let synthetic_endpoint =
    is_edge_vnode_name(tail) || is_edge_vnode_name(head) ||
    tail_is_skeleton || head_is_skeleton
  if !synthetic_endpoint {
    return false
  }
  let defaultish_x =
    (tail_port_x == 0.0 || tail_port_x == 0.5) &&
    (head_port_x == 0.0 || head_port_x == 0.5)
  if tail_is_skeleton && head_is_skeleton {
    return true
  }
  defaultish_x && tail_port_order == 0.0 && head_port_order == 0.0
}

///|
/// Graphviz parity: synthetic mincross endpoints keep default port values at
/// zero when Graphviz treats the endpoint pair as synthetic-only.
fn normalize_synthetic_mincross_ports(
  tail : String,
  head : String,
  tail_port_x_raw : Double,
  head_port_x_raw : Double,
  tail_port_order_raw : Double,
  head_port_order_raw : Double,
) -> (Double, Double, Double, Double) {
  let zero_synthetic_defaults =
    should_zero_synthetic_mincross_ports(
      tail,
      head,
      tail_port_x_raw,
      head_port_x_raw,
      tail_port_order_raw,
      head_port_order_raw,
    )
  if !zero_synthetic_defaults {
    return (
      tail_port_x_raw,
      head_port_x_raw,
      tail_port_order_raw,
      head_port_order_raw,
    )
  }
  (0.0, 0.0, 0.0, 0.0)
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
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
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
      let (tail_port_x, head_port_x, tail_port_order, head_port_order) =
        normalize_synthetic_mincross_ports(
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
      order_edge_tail_port_x_mincross.push(tail_port_x)
      order_edge_head_port_x_mincross.push(head_port_x)
      order_edge_tail_port_order_mincross.push(tail_port_order)
      order_edge_head_port_order_mincross.push(head_port_order)
    }
    edge_idx = edge_idx + 1
  }
  (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  )
}

///|
/// Graphviz parity: after root-only mincross, reordered root/skeleton nodes are
/// merged back into seeded rank lists by replacing only filtered positions.
/// Do not change behavior without updating fixtures/tests.
fn merge_root_mincross_order_into_seeded_groups(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  _order_cluster_keys : Map[String, String],
  _order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match seeded_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let replacements = match ordered_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    if replacements.length() == 0 {
      merged[rank] = names
      continue
    }
    // Graphviz parity: keep cluster-internal nodes attached to the rankleader
    // skeleton position when root mincross reorders cluster skeleton chains.
    let skeleton_for_cluster : Map[String, String] = Map::new()
    for name in names {
      if _order_cluster_skeleton.get(name) == Some(true) {
        let cluster = match _order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" {
          skeleton_for_cluster[cluster] = name
        }
      }
    }
    let attached_by_skeleton : Map[String, Array[String]] = Map::new()
    for name in names {
      if mincross_nodes.get(name) is Some(_) {
        continue
      }
      let cluster = match _order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
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
    // Graphviz parity: when root mincross returns [root, skeleton] in a
    // single-root rank, keep the attached cluster node in front via positional
    // replacement (matches biological rank handoff in Graphviz).
    let should_use_positional_merge =
      replacements.length() == 2 &&
      _order_cluster_skeleton.get(replacements[1]) == Some(true) &&
      _order_cluster_skeleton.get(replacements[0]) != Some(true) &&
      (match attached_by_skeleton.get(replacements[1]) {
        Some(list) => list.length()
        None => 0
      }) == 1
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
      if _order_cluster_skeleton.get(replacement) == Some(true) {
        let attached = match attached_by_skeleton.get(replacement) {
          Some(list) => list
          None => []
        }
        for attached_name in attached {
          if seen.get(attached_name) is None {
            next_names.push(attached_name)
            seen[attached_name] = true
          }
        }
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
/// Graphviz parity: root cluster reorder GD_nlist keeps skeleton/root tail
/// sequence from input order, prioritizes source tails, then rebuilds nlist via
/// edge creation order while appending any missing root nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_order_for_cluster_reorder(
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
      let rank = rank_or_zero_for_flat_constraints(ranks, name)
      let skel = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      append_order_creation_name_if_absent(
        tail_order_root,
        tail_root_seen,
        skel,
      )
    } else {
      append_order_creation_name_if_absent(
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
      append_order_creation_name_if_absent(
        root_tail_order,
        root_tail_seen,
        name,
      )
    }
  }
  for name in tail_order_root {
    append_order_creation_name_if_absent(
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
/// Graphviz parity: root cluster reorder groups keep root/skeleton base order
/// and optionally merge only root-vnodes into rank groups using filtered vnode
/// keys/rank buckets from root-mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_for_cluster_reorder(
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
  // Graphviz parity: root-vnode set for cluster root reorder includes vnodes
  // on edges crossing cluster boundaries (same edge_vnode_key mapping as routing).
  let root_vnodes : Map[String, Bool] = Map::new()
  if order_with_vnodes {
    let mut edge_idx = 0
    for edge in edges {
      let tail =
        if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
          edge.tail().name()
        }
      let head =
        if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
          edge.head().name()
        }
      let tail_cluster = match cluster_keys.get(tail) {
        Some(value) => value
        None => ""
      }
      let head_cluster = match cluster_keys.get(head) {
        Some(value) => value
        None => ""
      }
      if tail_cluster != head_cluster {
        let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
          Some(list) => list
          None => []
        }
        for vnode in vnodes {
          root_vnodes[vnode] = true
        }
      }
      edge_idx = edge_idx + 1
    }
  }
  // Graphviz parity: root cluster reorder base groups keep only root/skeleton
  // nodes, and include edge-vnodes only when flagged as root-vnodes.
  let root_groups_base : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match order_groups_for_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    let root_names : Array[String] = []
    for name in names {
      let cluster = match order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      if is_skeleton || cluster == "" {
        if !name.has_prefix(EDGE_VNODE_PREFIX) || root_vnodes.get(name) == Some(true) {
          root_names.push(name)
        }
      }
    }
    if root_names.length() > 0 {
      root_groups_base[rank] = root_names
    }
  }
  let root_order_index = build_order_index(root_groups_base)
  // Graphviz parity: root mincross vnode inputs keep only root-vnodes from
  // vnode rank buckets and vnode order keys.
  let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let root_vnode_order_keys : Map[String, Double] = Map::new()
  if order_with_vnodes {
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
  }
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      root_groups_base,
      root_order_index,
      root_vnodes_by_rank,
      root_vnode_order_keys,
    )
  } else {
    root_groups_base
  }
}

///|
/// Graphviz parity: root real-node bucket keeps relative left/right anchor
/// continuity across adjacent ranks when both ranks expose root buckets.
/// Do not change behavior without updating fixtures/tests.
fn anchor_root_bucket_from_previous_cluster_rank_order(
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
  // Graphviz parity: cluster-rank sort keys are normalized into deterministic
  // order for root-bucket anchor transfer across adjacent ranks.
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
  let left = match left_anchor {
    Some(value) => value
    None => return ()
  }
  let mut insert_idx = sorted_clusters.length()
  for i in 0..<sorted_clusters.length() {
    if sorted_clusters[i] == left {
      insert_idx = i + 1
      break
    }
  }
  if insert_idx > sorted_clusters.length() {
    return ()
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
/// and ordered-root groups tuple ordering unchanged before rank transfer.
/// Do not change behavior without updating fixtures/tests.
type RootClusterRankOrderPhaseOutput = (
  Array[Int],
  Map[Int, Array[String]],
)

///|
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
fn run_root_cluster_rank_order_phase_from_root_reorder_output(
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
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> RootClusterRankOrderPhaseOutput {
  let (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  ) = root_reorder_output
  // Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
  // path as cluster-phase root bucket ordering, with root-flip guarding.
  let seen_cluster_keys : Map[String, Bool] = Map::new()
  let mut has_multi_cluster_roots = false
  for _name, key in order_cluster_keys {
    if key == "" || seen_cluster_keys.get(key) is Some(_) {
      continue
    }
    seen_cluster_keys[key] = true
    if seen_cluster_keys.length() > 1 {
      has_multi_cluster_roots = true
      break
    }
  }
  let root_graphviz_flip =
    if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
      graphviz_flip
    } else {
      graphviz_flip && has_multi_cluster_roots
    }
  let ordered_root = reorder_rank_groups(
    root_rank_keys,
    root_groups,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    root_edge_order,
    root_node_order,
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
    return (root_rank_keys, ordered_root)
  }
  let ordered_root_nodes =
    build_order_nodes_from_groups(ordered_root, root_rank_keys)
  let ordered_root_mincross_nodes =
    build_node_membership_set(ordered_root_nodes)
  let merged_ordered_root =
    merge_root_mincross_order_into_seeded_groups(
      root_rank_keys,
      root_groups,
      ordered_root,
      ordered_root_mincross_nodes,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  (root_rank_keys, merged_ordered_root)
}


///|
/// Graphviz parity: root cluster-rank-order prep tuple alias keeps root
/// groups/edges/node-order field ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
type RootClusterReorderInputsForRankOrderOutput = (
  Map[Int, Array[String]],
  Array[Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Int],
)

///|
/// Graphviz parity: root reorder context + root edge bundle are materialized
/// before root-only mincross in cluster-order phase.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order(
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
) -> RootClusterReorderInputsForRankOrderOutput {
  let root_groups =
    build_root_groups_for_cluster_reorder(
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
  let (root_graph, root_node_map) =
    build_order_graph_and_nodes("order_root", root_nodes)
  // Graphviz parity: root cluster-reorder derives root GD_nlist walk order and
  // root-node order map from the same root graph/group membership snapshot.
  let root_nlist_order =
    build_root_nlist_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  // Graphviz parity: root/ReMincross node-order seeding follows GD_nlist
  // order and fills missing nodes from current rank-group index.
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
  let (
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
  ) =
    {
      // Graphviz parity: root reorder edge bundle keeps tail-sequence edge
      // materialization, optional trace output, and index maps in one stage.
      let (
        root_edges_out,
        root_edge_tail_out,
        root_edge_head_out,
        root_edge_tail_port_x,
        root_edge_head_port_x,
        root_edge_tail_port_order,
        root_edge_head_port_order,
      ) =
        collect_order_edges_for_tail_sequence(
          root_nlist_order,
          order_edges_by_tail_root,
          root_graph,
          root_node_map,
        )
      let root_edge_tail_port_x_norm : Array[Double] = []
      let root_edge_head_port_x_norm : Array[Double] = []
      let root_edge_tail_port_order_norm : Array[Double] = []
      let root_edge_head_port_order_norm : Array[Double] = []
      let mut root_port_idx = 0
      while root_port_idx < root_edges_out.length() {
        let tail = root_edge_tail_out[root_port_idx]
        let head = root_edge_head_out[root_port_idx]
        let tail_port_x_raw = root_edge_tail_port_x[root_port_idx]
        let head_port_x_raw = root_edge_head_port_x[root_port_idx]
        let tail_port_order_raw = root_edge_tail_port_order[root_port_idx]
        let head_port_order_raw = root_edge_head_port_order[root_port_idx]
        let (
          tail_port_x_norm,
          head_port_x_norm,
          tail_port_order_norm,
          head_port_order_norm,
        ) =
          normalize_synthetic_mincross_ports(
            tail,
            head,
            tail_port_x_raw,
            head_port_x_raw,
            tail_port_order_raw,
            head_port_order_raw,
          )
        root_edge_tail_port_x_norm.push(tail_port_x_norm)
        root_edge_head_port_x_norm.push(head_port_x_norm)
        root_edge_tail_port_order_norm.push(tail_port_order_norm)
        root_edge_head_port_order_norm.push(head_port_order_norm)
        root_port_idx = root_port_idx + 1
      }
      let (root_parents, root_children, root_edge_order) =
        build_order_edge_indices_and_order(
          root_nodes,
          root_edge_tail_out,
          root_edge_head_out,
          root_ranks,
          root_edges_out,
        )
      (
        root_edges_out,
        root_edge_tail_out,
        root_edge_head_out,
        root_edge_tail_port_x_norm,
        root_edge_head_port_x_norm,
        root_edge_tail_port_order_norm,
        root_edge_head_port_order_norm,
        root_parents,
        root_children,
        root_edge_order,
      )
    }
  (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  )
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_cluster_reorder(
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
    build_root_cluster_reorder_inputs_for_rank_order(
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
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let (root_rank_keys, ordered_root) =
    run_root_cluster_rank_order_phase_from_root_reorder_output(
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
  // Graphviz parity: root mincross rank map records first-seen cluster skeleton
  // (or root real-node bucket) order per rank for cluster-phase reordering.
  let mut previous_order_map : Map[String, Int]? = None
  for rank in root_rank_keys {
    let names = match ordered_root.get(rank) {
      Some(list) => list
      None => []
    }
    let order_map : Map[String, Int] = Map::new()
    let mut idx = 0
    for name in names {
      if order_cluster_skeleton.get(name) == Some(true) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" && order_map.get(cluster) is None {
          order_map[cluster] = idx
          idx = idx + 1
        }
      } else if real_nodes.get(name) is Some(_) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster == "" && order_map.get("") is None {
          order_map[""] = idx
          idx = idx + 1
        }
      }
    }
    anchor_root_bucket_from_previous_cluster_rank_order(
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
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
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
fn reorder_rank_names_by_override(
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
/// Graphviz parity: root phase can apply a rank-order override from root
/// mincross output before local cluster passes.
/// Do not change behavior without updating fixtures/tests.
fn apply_root_rank_groups_override(
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
          reorder_rank_names_by_override(
            names,
            override_names,
          )
        if !graphviz_flip {
          reordered[rank] = rank_names
          continue
        }
        let skeleton_for_cluster : Map[String, String] = Map::new()
        for name in rank_names {
          let skeleton_cluster = match cluster_key_from_skeleton_name(name) {
            Some(value) => value
            None => ""
          }
          let is_skeleton = skeleton_cluster != ""
          if is_skeleton {
            let cluster =
              if skeleton_cluster != "" { skeleton_cluster } else {
                cluster_key_or_empty(cluster_keys, name)
              }
            if cluster != "" {
              skeleton_for_cluster[cluster] = name
            }
          }
        }
        let attached_by_skeleton : Map[String, Array[String]] = Map::new()
        for name in rank_names {
          let is_skeleton =
            (match cluster_key_from_skeleton_name(name) {
              Some(_) => true
              None => false
            })
          if is_skeleton {
            continue
          }
          let cluster = cluster_key_or_empty(cluster_keys, name)
          if cluster == "" {
            continue
          }
          match skeleton_for_cluster.get(cluster) {
            Some(skel) =>
              match attached_by_skeleton.get(skel) {
                Some(list) => list.push(name)
                None => attached_by_skeleton[skel] = [name]
              }
            None => ()
          }
        }
        let next_names : Array[String] = []
        let seen : Map[String, Bool] = Map::new()
        for name in rank_names {
          if seen.get(name) is Some(_) {
            continue
          }
          let skeleton_cluster = match cluster_key_from_skeleton_name(name) {
            Some(value) => value
            None => ""
          }
          let is_skeleton = skeleton_cluster != ""
          if is_skeleton {
            next_names.push(name)
            seen[name] = true
            let attached = match attached_by_skeleton.get(name) {
              Some(list) => list
              None => []
            }
            for attached_name in attached {
              if seen.get(attached_name) is None {
                next_names.push(attached_name)
                seen[attached_name] = true
              }
            }
            continue
          }
          let cluster = cluster_key_or_empty(cluster_keys, name)
          if cluster != "" &&
            (match skeleton_for_cluster.get(cluster) {
              Some(_) => true
              None => false
            }) {
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
        reordered[rank] = next_names
      }
      None => ()
    }
  }
  reordered
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_groups_by_cluster_rank_order(
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
    if names.length() > 2 {
      let mut first_cluster = -1
      let mut last_cluster = -1
      let mut root_before = false
      let mut root_after = false
      for i in 0..<names.length() {
        let cluster = cluster_key_or_empty(cluster_keys, names[i])
        if cluster != "" {
          if first_cluster < 0 {
            first_cluster = i
          }
          last_cluster = i
        }
      }
      if first_cluster >= 0 {
        for i in 0..<first_cluster {
          if cluster_key_or_empty(cluster_keys, names[i]) == "" {
            root_before = true
            break
          }
        }
        if last_cluster + 1 < names.length() {
          for i in (last_cluster + 1)..<names.length() {
            if cluster_key_or_empty(cluster_keys, names[i]) == "" {
              root_after = true
              break
            }
          }
        }
      }
      if root_before && root_after {
        ordered_by_cluster[rank] = names
        continue
      }
    }
    // Graphviz parity: cluster reorder buckets keep first-seen cluster
    // sequence and preserve per-cluster node order within each rank.
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
    // stable first-seen sequence fallback for clusters missing from the map.
    let cluster_ordered : Array[(Int, Int, String)] = []
    for idx, cluster in cluster_seq {
      let base =
        match order_map.get(cluster) {
          Some(value) => value
          None => order_map.length() + idx
        }
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
    // Graphviz parity: cluster bucket flattening emits clusters in sorted
    // bucket order while preserving each cluster's original node sequence.
    let ordered_names : Array[String] = []
    for entry in cluster_ordered {
      let (_order, _idx, cluster) = entry
      let nodes_in_cluster = match cluster_nodes.get(cluster) {
        Some(list) => list
        None => []
      }
      for name in nodes_in_cluster {
        ordered_names.push(name)
      }
    }
    ordered_by_cluster[rank] = ordered_names
  }
  ordered_by_cluster
}
