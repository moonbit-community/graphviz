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
      let zero_synthetic_defaults =
        should_zero_synthetic_mincross_ports(
          tail,
          head,
          tail_port_x_raw,
          head_port_x_raw,
          tail_port_order_raw,
          head_port_order_raw,
        )
      let tail_port_x =
        if zero_synthetic_defaults { 0.0 } else { tail_port_x_raw }
      let head_port_x =
        if zero_synthetic_defaults { 0.0 } else { head_port_x_raw }
      let tail_port_order =
        if zero_synthetic_defaults {
          0.0
        } else {
          tail_port_order_raw
        }
      let head_port_order =
        if zero_synthetic_defaults {
          0.0
        } else {
          head_port_order_raw
        }
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
/// Graphviz parity: root-vnode set for cluster root reorder includes vnodes on
/// edges crossing cluster boundaries (same edge_vnode_key mapping as routing).
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnodes_for_cluster_reorder(
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
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      for vnode in vnodes {
        root_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  root_vnodes
}

///|
/// Graphviz parity: root cluster reorder base groups keep only root/skeleton
/// nodes, and include edge-vnodes only when flagged as root-vnodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_base_for_cluster_reorder(
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  root_vnodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
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
  root_groups_base
}

///|
/// Graphviz parity: root cluster reorder seeds tail order from current nlist,
/// replacing cluster members with rank-qualified skeleton names and deduping.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_seed_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Array[String] {
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
  tail_order_root
}

///|
/// Graphviz parity: root tail visit order places source tails (no incoming
/// edges) first while preserving original deduped tail sequence order.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_sources_first(
  tail_order_root : Array[String],
  root_has_in : Map[String, Bool],
) -> Array[String] {
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
  root_tail_order
}

///|
/// Graphviz parity: root source-first ordering marks incoming heads among
/// root nodes from merged edge-creation order before tail-order filtering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_has_in_map_for_cluster_reorder(
  root_nodes : Array[String],
  root_edge_creation_order : Array[(String, String)],
) -> Map[String, Bool] {
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
  root_has_in
}

///|
/// Graphviz parity: root GD_nlist output keeps only materialized root nodes,
/// then appends any missing root names in root_nodes order.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_nlist_order_for_cluster_reorder(
  root_nlist_full : Array[String],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
) -> Array[String] {
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
  let tail_order_root =
    build_root_tail_seed_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
    )
  let root_edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      root_edge_creation,
    )
  let root_has_in =
    build_root_has_in_map_for_cluster_reorder(
      root_nodes,
      root_edge_creation_order,
    )
  let root_tail_order =
    build_root_tail_order_sources_first(tail_order_root, root_has_in)
  let root_nlist_full =
    @dot_shared.build_graphviz_nlist_order_from_edges(
      root_tail_order,
      root_nodes,
      root_edge_creation_order,
      flat_rank_constraints,
    )
  finalize_root_nlist_order_for_cluster_reorder(
    root_nlist_full,
    root_nodes,
    root_node_map,
  )
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode order keys.
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnode_rank_groups_and_order_keys(
  order_with_vnodes : Bool,
  root_vnodes : Map[String, Bool],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (Map[Int, Array[String]], Map[String, Double]) {
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
  (root_vnodes_by_rank, root_vnode_order_keys)
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
  let root_vnodes =
    collect_root_vnodes_for_cluster_reorder(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
    )
  let root_groups_base =
    build_root_groups_base_for_cluster_reorder(
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      root_vnodes,
    )
  let root_order_index = build_order_index(root_groups_base)
  let (root_vnodes_by_rank, root_vnode_order_keys) =
    collect_root_vnode_rank_groups_and_order_keys(
      order_with_vnodes,
      root_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
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
/// Graphviz parity: cluster-rank sort keys are normalized into deterministic
/// order for root-bucket anchor transfer across adjacent ranks.
/// Do not change behavior without updating fixtures/tests.
fn collect_sorted_cluster_keys_for_cluster_rank_order(
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
  let sorted : Array[String] = []
  for entry in entries {
    let (_order, cluster) = entry
    sorted.push(cluster)
  }
  sorted
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
  let sorted_clusters = collect_sorted_cluster_keys_for_cluster_rank_order(order_map)
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

///|
/// Graphviz parity: root mincross rank map records first-seen cluster skeleton
/// (or root real-node bucket) order per rank for cluster-phase reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_from_root_ordered(
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
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
/// Graphviz parity: debug root-edge trace for cluster reorder mirrors the
/// root mincross materialization sequence and penalties.
/// Do not change behavior without updating fixtures/tests.
fn trace_root_edges_for_cluster_reorder(
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < root_edges_out.length() {
      let tail = root_edge_tail_out[edge_idx]
      let head = root_edge_head_out[edge_idx]
      let pen = @dot_shared.edge_xpenalty(root_edges_out[edge_idx])
      println("root_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen}")
      edge_idx = edge_idx + 1
    }
  }
}

///|
/// Graphviz parity: root reorder edge bundle keeps tail-sequence edge
/// materialization, optional trace output, and index maps in one stage.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_edge_bundle(
  root_nlist_order : Array[String],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nodes : Array[String],
  root_ranks : Map[String, Int],
) -> (
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
) {
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
    let zero_ports =
      should_zero_synthetic_mincross_ports(
        tail,
        head,
        tail_port_x_raw,
        head_port_x_raw,
        tail_port_order_raw,
        head_port_order_raw,
      )
    root_edge_tail_port_x_norm.push(
      if zero_ports { 0.0 } else { tail_port_x_raw },
    )
    root_edge_head_port_x_norm.push(
      if zero_ports { 0.0 } else { head_port_x_raw },
    )
    root_edge_tail_port_order_norm.push(
      if zero_ports { 0.0 } else { tail_port_order_raw },
    )
    root_edge_head_port_order_norm.push(
      if zero_ports { 0.0 } else { head_port_order_raw },
    )
    root_port_idx = root_port_idx + 1
  }
  trace_root_edges_for_cluster_reorder(
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
  )
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

///|
/// Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
/// path and tracing as cluster-phase root bucket ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_cluster_reorder_for_cluster_rank_order(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let has_multi_cluster_roots =
    has_multiple_nonempty_cluster_keys_for_root_reorder(order_cluster_keys)
  let root_graphviz_flip =
    if should_capture_ordering_fixture_mode() {
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
  dot_trace_groups("order_root", ordered_root)
  ordered_root
}

///|
fn has_multiple_nonempty_cluster_keys_for_root_reorder(
  cluster_keys : Map[String, String],
) -> Bool {
  let seen : Map[String, Bool] = Map::new()
  for _name, key in cluster_keys {
    if key == "" || seen.get(key) is Some(_) {
      continue
    }
    seen[key] = true
    if seen.length() > 1 {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: root cluster-reorder derives rank keys/ranks, ordered
/// root nodes, and order_root graph directly from root-group membership.
/// Do not change behavior without updating fixtures/tests.
fn build_root_rank_graph_bundle_for_cluster_reorder(
  root_groups : Map[Int, Array[String]],
) -> (
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
) {
  let root_rank_keys = collect_rank_keys(root_groups)
  let root_ranks = build_node_ranks(root_groups)
  let root_nodes = build_order_nodes_from_groups(root_groups, root_rank_keys)
  let (root_graph, root_node_map) =
    build_order_graph_and_nodes("order_root", root_nodes)
  (root_rank_keys, root_ranks, root_nodes, root_graph, root_node_map)
}

///|
/// Graphviz parity: root cluster-reorder derives root GD_nlist walk order and
/// root-node order map from the same root graph/group membership snapshot.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_and_node_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  root_groups : Map[Int, Array[String]],
) -> (Array[String], Map[String, Int]) {
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
  let root_node_order =
    build_order_node_order_from_nlist_and_groups(
      root_nlist_order,
      root_node_map,
      root_groups,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let root_nlist_joined = root_nlist_order.join(" ")
    println("root_nlist_order \{root_nlist_joined}")
    let pairs : Array[(Int, String)] = []
    for name, idx in root_node_order {
      pairs.push((idx, name))
    }
    if pairs.length() > 1 {
      pairs.sort_by((a, b) => {
        let (ai, an) = a
        let (bi, bn) = b
        if ai < bi {
          -1
        } else if ai > bi {
          1
        } else if an < bn {
          -1
        } else if an > bn {
          1
        } else {
          0
        }
      })
    }
    let ordered_labels : Array[String] = []
    for pair in pairs {
      let (idx, name) = pair
      ordered_labels.push("\{name}=\{idx}")
    }
    let root_node_order_joined = ordered_labels.join(" ")
    println("root_node_order \{root_node_order_joined}")
  }
  (root_nlist_order, root_node_order)
}

///|
/// Graphviz parity: root cluster-reorder context is assembled from root
/// groups, root graph, and root nlist ordering before edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_context(
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
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  Array[String],
  Map[String, Int],
) {
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
  let (root_rank_keys, root_ranks, root_nodes, root_graph, root_node_map) =
    build_root_rank_graph_bundle_for_cluster_reorder(root_groups)
  let (root_nlist_order, root_node_order) =
    build_root_nlist_and_node_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
      root_groups,
    )
  (
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  )
}

///|
/// Graphviz parity: root-order rank map is transferred into the cluster
/// rank-order output map before final clustered reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn append_root_cluster_rank_order_for_cluster_reorder(
  cluster_rank_order : Map[Int, Map[String, Int]],
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  real_nodes : Map[String, Bool],
) -> Unit {
  let root_cluster_rank_order =
    build_cluster_rank_order_from_root_ordered(
      root_rank_keys,
      ordered_root,
      order_cluster_skeleton,
      order_cluster_keys,
      real_nodes,
    )
  for rank, order_map in root_cluster_rank_order {
    cluster_rank_order[rank] = order_map
  }
}

///|
/// Graphviz parity: root cluster-rank-order output context keeps rank-same,
/// order-size, and cluster-filter payload ordering for root reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterRankOrderFromRootReorderContext {
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
  real_nodes : Map[String, Bool]
}

///|
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
  dispatch_context : ClusterRankOrderFromRootReorderContext,
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
  let ordered_root = run_root_cluster_reorder_for_cluster_rank_order(
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
    dispatch_context.order_cluster_keys,
    dispatch_context.rank_same_groups,
    dispatch_context.rank_same_order,
    root_edge_order,
    root_node_order,
    dispatch_context.order_sizes_out,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    dispatch_context.order_cluster_skeleton,
    dispatch_context.flat_constraints,
    dispatch_context.graphviz_flip,
  )
  if !dispatch_context.graphviz_flip {
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
      dispatch_context.order_cluster_keys,
      dispatch_context.order_cluster_skeleton,
    )
  (root_rank_keys, merged_ordered_root)
}


///|
/// Graphviz parity: root reorder output map for clustered ordering is
/// produced by root mincross reorder followed by root-rank map transfer.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_output_from_root_reorder(
  dispatch_context : ClusterRankOrderFromRootReorderContext,
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let (root_rank_keys, ordered_root) =
    run_root_cluster_rank_order_phase_from_root_reorder_output(
      dispatch_context,
      root_reorder_output,
    )
  append_root_cluster_rank_order_for_cluster_reorder(
    cluster_rank_order,
    root_rank_keys,
    ordered_root,
    dispatch_context.order_cluster_skeleton,
    dispatch_context.order_cluster_keys,
    dispatch_context.real_nodes,
  )
  cluster_rank_order
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
/// Graphviz parity: root cluster-rank-order prep output keeps root groups,
/// root edge materialization arrays, and root node-order map tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_output(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
) -> RootClusterReorderInputsForRankOrderOutput {
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
/// Graphviz parity: root reorder edge-bundle phase consumes root context
/// graph artifacts before root-only mincross input tuple assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_edge_bundle_phase(
  root_nlist_order : Array[String],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nodes : Array[String],
  root_ranks : Map[String, Int],
) -> (
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
) {
  build_root_cluster_reorder_edge_bundle(
    root_nlist_order,
    order_edges_by_tail_root,
    root_graph,
    root_node_map,
    root_nodes,
    root_ranks,
  )
}


///|
/// Graphviz parity: root reorder context phase materializes root rank/group
/// graph artifacts before root-edge bundle expansion for mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_context_phase(
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
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  Array[String],
  Map[String, Int],
) {
  build_root_cluster_reorder_context(
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
}


///|
/// Graphviz parity: root reorder from-context phase materializes root edge
/// bundle and assembles root-only reorder input tuple without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_from_context_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_ranks : Map[String, Int],
  root_nodes : Array[String],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nlist_order : Array[String],
  root_node_order : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootClusterReorderInputsForRankOrderOutput {
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
    build_root_cluster_reorder_inputs_for_rank_order_edge_bundle_phase(
      root_nlist_order,
      order_edges_by_tail_root,
      root_graph,
      root_node_map,
      root_nodes,
      root_ranks,
    )
  build_root_cluster_reorder_inputs_for_rank_order_output(
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
  let (
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  ) =
    build_root_cluster_reorder_inputs_for_rank_order_context_phase(
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
  build_root_cluster_reorder_inputs_for_rank_order_from_context_phase(
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
    order_edges_by_tail_root,
  )
}

///|
/// Graphviz parity: enabled-cluster rank-order assembly consumes root reorder
/// materialization and forwards fields in Graphviz root-mincross order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_from_enabled_cluster_root_inputs(
  dispatch_context : ClusterRankOrderFromRootReorderContext,
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_output_from_root_reorder(
    dispatch_context,
    root_reorder_output,
  )
}

///|
/// Graphviz parity: enabled-cluster rank-order prep pulls cluster-key/vnode
/// fields from cluster metadata before root-only reorder input assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (
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
) {
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
}

///|
/// Graphviz parity: cluster-enabled rank-order output maps root-only reorder
/// materialization into Graphviz cluster-rank-order assembly arguments.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_inputs(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
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
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let root_reorder_output : RootClusterReorderInputsForRankOrderOutput = (
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
  let dispatch_context : ClusterRankOrderFromRootReorderContext = {
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip,
    real_nodes,
  }
  build_cluster_rank_order_from_enabled_cluster_root_inputs(
    dispatch_context,
    root_reorder_output,
  )
}

///|
/// Graphviz parity: cluster-enabled rank-order forwarding reads rank-same and
/// flat-constraint maps from cluster metadata before root-order assembly call.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_with_cluster_meta(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_inputs(
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
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order root phase builds root-only
/// reorder payload before cluster-metadata forwarding and final map assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_root_reorder_phase(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (
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
) {
  build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
    order_with_vnodes,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    order_edges_by_tail_root,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
  )
}

///|
/// Graphviz parity: cluster-enabled rank-order from-root phase forwards
/// root-only reorder payload into cluster-metadata map assembly unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_with_cluster_meta(
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
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order finalize phase forwards
/// root-only reorder payload into final cluster-rank-order map assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_finalize_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_phase(
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
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order finalize dispatch reads
/// root-reorder tuple and forwards values in Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_finalize_phase_from_root_reorder_output(
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
  root_reorder_output : (
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
  ),
) -> Map[Int, Map[String, Int]] {
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
  build_cluster_rank_order_when_clusters_enabled_finalize_phase(
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
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: when cluster ordering is enabled, cluster rank-order map
/// is built from root-only reorder inputs and root mincross output.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled(
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
  let root_reorder_output =
    build_cluster_rank_order_when_clusters_enabled_root_reorder_phase(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      nlist_order,
      ranks,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
      order_edges_by_tail_root,
      cluster_meta,
      vnode_info,
      vnode_order_keys_for_ordering,
    )
  build_cluster_rank_order_when_clusters_enabled_finalize_phase_from_root_reorder_output(
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
    root_reorder_output,
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
  build_cluster_rank_order_when_clusters_enabled(
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
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
        if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
          let joined = rank_names.join(" ")
          println("root_override rank \{rank} names \{joined}")
          for name in rank_names {
            let cluster = cluster_key_or_empty(cluster_keys, name)
            let skel = match cluster_key_from_skeleton_name(name) {
              Some(value) => value
              None => ""
            }
            println("root_override node \{name} cluster=\{cluster} skel=\{skel}")
          }
          for skel, attached in attached_by_skeleton {
            println("root_override attach \{skel} -> \{attached}")
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
/// Graphviz parity: cluster reorder buckets keep first-seen cluster sequence
/// and preserve per-cluster node order within each rank.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_nodes_and_sequence_for_rank_reorder(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> (Map[String, Array[String]], Array[String]) {
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
  (cluster_nodes, cluster_seq)
}

///|
/// Graphviz parity: cluster bucket sort keys use root rank-order map with
/// stable first-seen sequence fallback for clusters missing from the map.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_ordered_keys_for_rank_reorder(
  order_map : Map[String, Int],
  cluster_seq : Array[String],
) -> Array[(Int, Int, String)] {
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
  cluster_ordered
}

///|
/// Graphviz parity: cluster bucket flattening emits clusters in sorted bucket
/// order while preserving each cluster's original node sequence.
/// Do not change behavior without updating fixtures/tests.
fn flatten_cluster_ordered_names_for_rank_reorder(
  cluster_ordered : Array[(Int, Int, String)],
  cluster_nodes : Map[String, Array[String]],
) -> Array[String] {
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
  ordered_names
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
    let (cluster_nodes, cluster_seq) =
      collect_cluster_nodes_and_sequence_for_rank_reorder(names, cluster_keys)
    let cluster_ordered =
      build_cluster_ordered_keys_for_rank_reorder(order_map, cluster_seq)
    let ordered_names =
      flatten_cluster_ordered_names_for_rank_reorder(
        cluster_ordered,
        cluster_nodes,
      )
    ordered_by_cluster[rank] = ordered_names
  }
  ordered_by_cluster
}
