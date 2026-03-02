///|
/// Stage C Phase C3 split: cluster-local reorder/build-ranks
/// helpers isolated from other Stage C phases.

///|
/// Graphviz parity: local cluster ordering uses minrank + first node order (cluster.c).
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_order(
  nodes : Array[@cgraph.Node],
  local_cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  // Graphviz parity: local cluster ordering seeds per-cluster minimum rank and
  // first-seen node order prior to stable cluster sorting.
  let min_rank : Map[String, Int] = Map::new()
  let first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match local_cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match min_rank.get(cluster) {
      Some(current) => if rank < current { min_rank[cluster] = rank }
      None => min_rank[cluster] = rank
    }
    if first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      first_order[cluster] = order_value
    }
  }
  // Graphviz parity: local cluster order entries are sorted by min rank, then
  // first node order, then cluster name for deterministic stable ordering.
  let entries : Array[(String, Int, Int)] = []
  for cluster, rank in min_rank {
    let order = match first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    entries.push((cluster, rank, order))
  }
  entries.sort_by((a, b) => {
    let (name_a, rank_a, order_a) = a
    let (name_b, rank_b, order_b) = b
    if rank_a < rank_b {
      -1
    } else if rank_a > rank_b {
      1
    } else if order_a < order_b {
      -1
    } else if order_a > order_b {
      1
    } else if name_a < name_b {
      -1
    } else if name_a > name_b {
      1
    } else {
      0
    }
  })
  // Graphviz parity: sorted local cluster entries are assigned contiguous order
  // ids in traversal order for clustered mincross passes.
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for entry in entries {
    let (cluster, _rank, _order) = entry
    if order_map.get(cluster) is None {
      order_map[cluster] = idx
      idx = idx + 1
    }
  }
  order_map
}

///|
/// Graphviz parity: local-cluster stable sorts compare seed order first and
/// break ties by node name to keep deterministic fixture ordering.
fn compare_by_order_then_name(
  order_map : Map[String, Int],
  a : String,
  b : String,
) -> Int {
  let a_idx = match order_map.get(a) {
    Some(value) => value
    None => 0
  }
  let b_idx = match order_map.get(b) {
    Some(value) => value
    None => 0
  }
  if a_idx < b_idx {
    -1
  } else if a_idx > b_idx {
    1
  } else if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

fn cluster_depth_for_order_inner(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
  visiting : Map[String, Bool],
) -> Int {
  match memo.get(cluster) {
    Some(value) => value
    None => {
      if visiting.get(cluster) is Some(_) {
        return 0
      }
      visiting[cluster] = true
      // Graphviz parity: cluster parent lookup prefers explicit traversal hints
      // and falls back to collected parent graph edges.
      let candidate : String? = match parents.get(cluster) {
        Some(value) => value
        None =>
          match fallback_parents.get(cluster) {
            Some(value) => value
            None => None
          }
      }
      let parent_opt : String? =
        match candidate {
          Some(value) =>
            if value == "" || value == cluster {
              None
            } else {
              Some(value)
            }
          None => None
        }
      let depth = match parent_opt {
        Some(parent) =>
          cluster_depth_for_order_inner(
            parent,
            parents,
            fallback_parents,
            memo,
            visiting,
          ) + 1
        None => 0
      }
      memo[cluster] = depth
      depth
    }
  }
}

///|
/// Graphviz parity: cluster traversal order index is seeded from Graphviz
/// cluster_order for tie-breaking during local cluster passes.
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_index(
  cluster_order : Array[String],
) -> Map[String, Int] {
  let cluster_index : Map[String, Int] = Map::new()
  for idx, name in cluster_order {
    cluster_index[name] = idx
  }
  cluster_index
}



///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_graph_order(
  graph : @cgraph.Graph,
  cluster_order : Array[String],
  cluster_parents_hint : Map[String, String?],
) -> (Map[String, @cgraph.Graph], Array[String]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @dot_shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let cluster_names : Array[String] = []
  for name, _ in cluster_graphs {
    cluster_names.push(name)
  }
  if cluster_graphs.length() == 0 {
    return (cluster_graphs, cluster_names)
  }
  let cluster_index = build_local_cluster_index(cluster_order)
  let cluster_depth : Map[String, Int] = Map::new()
  if cluster_names.length() > 1 {
    cluster_names.sort_by((a, b) => {
      let a_depth =
        cluster_depth_for_order_inner(
          a,
          cluster_parents_hint,
          cluster_parents,
          cluster_depth,
          Map::new(),
        )
      let b_depth =
        cluster_depth_for_order_inner(
          b,
          cluster_parents_hint,
          cluster_parents,
          cluster_depth,
          Map::new(),
        )
      if a_depth < b_depth {
        -1
      } else if a_depth > b_depth {
        1
      } else {
        let a_idx = match cluster_index.get(a) {
          Some(value) => value
          None => cluster_index.length() + 1
        }
        let b_idx = match cluster_index.get(b) {
          Some(value) => value
          None => cluster_index.length() + 1
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
  }
  (cluster_graphs, cluster_names)
}

///|
/// Graphviz parity: local cluster rank groups include only cluster members and
/// seed each rank from previous-rank ND_out reachability before seed-order
/// fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_local_rank_groups(
  groups : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
  cluster_node_order : Map[String, Int],
  source_graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let cluster_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    let list : Array[String] = []
    for name in names {
      if cluster_node_set.get(name) is Some(_) {
        list.push(name)
      }
    }
    if list.length() > 1 {
      let real_nodes : Array[String] = []
      for name in list {
        if !is_edge_vnode_name(name) {
          real_nodes.push(name)
        }
      }
      if real_nodes.length() > 1 {
        real_nodes.sort_by((a, b) => {
          compare_by_order_then_name(cluster_node_order, a, b)
        })
        let mut real_idx = 0
        for i in 0..<list.length() {
          if is_edge_vnode_name(list[i]) {
            continue
          }
          list[i] = real_nodes[real_idx]
          real_idx = real_idx + 1
        }
      }
    }
    if list.length() > 0 {
      cluster_groups[rank] = list
    }
  }
  let out_heads_by_tail : Map[String, Array[String]] = Map::new()
  for tail, _ in cluster_node_set {
    let heads = match source_graphviz_out_neighbors.get(tail) {
      Some(value) => value
      None => []
    }
    let filtered : Array[String] = []
    for head in heads {
      if cluster_node_set.get(head) is Some(_) {
        filtered.push(head)
      }
    }
    if filtered.length() > 0 {
      out_heads_by_tail[tail] = filtered
    }
  }
  let cluster_rank_keys = collect_rank_keys(cluster_groups)
  for rank in cluster_rank_keys {
    let list = match cluster_groups.get(rank) {
      Some(value) => value
      None => continue
    }
    if list.length() <= 1 {
      continue
    }
    let real_nodes : Array[String] = []
    let real_set : Map[String, Bool] = Map::new()
    for name in list {
      if !is_edge_vnode_name(name) {
        real_nodes.push(name)
        real_set[name] = true
      }
    }
    if real_nodes.length() <= 1 {
      continue
    }
    let seeded_real_nodes : Array[String] = []
    let seeded_seen : Map[String, Bool] = Map::new()
    let prev_names = match cluster_groups.get(rank - 1) {
      Some(value) => value
      None => []
    }
    for tail in prev_names {
      let heads = match out_heads_by_tail.get(tail) {
        Some(value) => value
        None => []
      }
      for head in heads {
        if real_set.get(head) is Some(_) && seeded_seen.get(head) is None {
          seeded_real_nodes.push(head)
          seeded_seen[head] = true
        }
      }
    }
    let fallback_real_nodes = real_nodes.copy()
    fallback_real_nodes.sort_by((a, b) => {
      compare_by_order_then_name(cluster_node_order, a, b)
    })
    for name in fallback_real_nodes {
      if seeded_seen.get(name) is None {
        seeded_real_nodes.push(name)
        seeded_seen[name] = true
      }
    }
    let mut real_idx = 0
    for i in 0..<list.length() {
      if is_edge_vnode_name(list[i]) {
        continue
      }
      list[i] = seeded_real_nodes[real_idx]
      real_idx = real_idx + 1
    }
  }
  cluster_groups
}



///|
/// Graphviz parity: cluster-local ND_out/ND_in maps append raw graph AGSEQ
/// neighbors after order-graph replay, skipping duplicates to mirror fixture
/// out_all/in_all merge behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_local_neighbor_maps(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_nodes : Array[String],
  source_graphviz_out_neighbors : Map[String, Array[String]],
  source_graphviz_in_neighbors : Map[String, Array[String]],
  raw_graphviz_out_neighbors : Map[String, Array[String]],
  raw_graphviz_in_neighbors : Map[String, Array[String]],
  intercluster_keys : Map[String, String],
  allow_raw_neighbors : Bool,
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let append_unique = (list : Array[String], value : String) => {
    let mut exists = false
    for item in list {
      if item == value {
        exists = true
        break
      }
    }
    if !exists {
      list.push(value)
    }
  }
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  let cluster_node_set : Map[String, Bool] = Map::new()
  let cluster_key_or_empty = (name : String) => {
    match intercluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
  }
  let external_anchor_name = "%0"
  let normalize_external_neighbor = (other : String) => {
    let other_cluster = cluster_key_or_empty(other)
    if other_cluster != "" && other_cluster != cluster &&
      expanded_clusters.get(other_cluster) is None {
      external_anchor_name
    } else {
      other
    }
  }
  for name in cluster_nodes {
    cluster_node_set[name] = true
  }
  let has_source_external_anchor = (name : String) => {
    let out = match source_graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    for other in out {
      if cluster_node_set.get(other) is None {
        return true
      }
    }
    let inn = match source_graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    for other in inn {
      if cluster_node_set.get(other) is None {
        return true
      }
    }
    false
  }
  let append_raw_neighbors_with_external_anchor = (
    neighbors : Array[String],
    raw_neighbors : Array[String],
  ) => {
    let external_cluster_seen : Map[String, Bool] = Map::new()
    for other in raw_neighbors {
      if is_edge_vnode_name(other) || other.has_prefix(CLUSTER_SKELETON_PREFIX) {
        continue
      }
      let normalized = normalize_external_neighbor(other)
      if normalized == external_anchor_name {
        let external_cluster = cluster_key_or_empty(other)
        if external_cluster == "" ||
          external_cluster_seen.get(external_cluster) is Some(_) {
          continue
        }
        external_cluster_seen[external_cluster] = true
        neighbors.push(normalized)
      } else {
        append_unique(neighbors, normalized)
      }
    }
  }
  for name in cluster_nodes {
    let out_neighbors = match source_graphviz_out_neighbors.get(name) {
      Some(list) => list.copy()
      None => []
    }
    let in_neighbors = match source_graphviz_in_neighbors.get(name) {
      Some(list) => list.copy()
      None => []
    }
    if allow_raw_neighbors && !has_source_external_anchor(name) {
      let raw_out = match raw_graphviz_out_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      append_raw_neighbors_with_external_anchor(out_neighbors, raw_out)
      let raw_in = match raw_graphviz_in_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      append_raw_neighbors_with_external_anchor(in_neighbors, raw_in)
    }
    graphviz_out_neighbors[name] = out_neighbors
    graphviz_in_neighbors[name] = in_neighbors
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_reorder(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  cluster_edges : Array[@cgraph.Edge],
  cluster_edge_tail : Array[String],
  cluster_edge_head : Array[String],
  cluster_edge_tail_port_x : Array[Double],
  cluster_edge_head_port_x : Array[Double],
  cluster_edge_tail_port_order : Array[Double],
  cluster_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  cluster_node_order : Map[String, Int],
  cluster_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  empty_cluster_skeleton : Map[String, Bool],
  cluster_flat_constraints : Map[String, Bool],
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
) -> (Bool, Map[Int, Array[String]]) {
  if cluster_edges.length() == 0 && cluster_flat_constraints.length() == 0 {
    return (false, Map::new())
  }
  let seeded_by_vnode_interp =
    seed_local_groups_by_vnode(
      cluster_rank_keys,
      cluster_groups,
      fixed_ranks,
      parents,
      children,
    )
  // Graphviz parity: mincross_clust() runs flat_reorder before mincross(g,2).
  let seeded_cluster_groups =
    flat_reorder_rank_groups(
      cluster_rank_keys,
      seeded_by_vnode_interp,
      fixed_ranks,
      cluster_flat_constraints,
      false,
    )
  let ordered_cluster =
    reorder_rank_groups(
      cluster_rank_keys,
      seeded_cluster_groups,
      cluster_edges,
      cluster_edge_tail,
      cluster_edge_head,
      cluster_edge_tail_port_x,
      cluster_edge_head_port_x,
      cluster_edge_tail_port_order,
      cluster_edge_head_port_order,
      parents,
      children,
      cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order,
      cluster_node_order,
      cluster_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      Map::new(),
      empty_cluster_skeleton,
      cluster_flat_constraints,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
      // Graphviz parity: subgraphs use effective rankdir=TB, so flip is false.
      fixed_positions=fixed_positions,
      fixed_ranks=fixed_ranks,
      graphviz_flip=false,
      // Graphviz parity: cluster-local startpass=2 mincross coalesces
      // parallel edge segments by endpoint+port order and sums xpenalty.
      coalesce_parallel_edges=true,
      startpass=2,
      startpass_init_infinite=false,
  )
  (true, ordered_cluster)
}

///|
/// Graphviz parity: vnode interpolation picks the first neighbor that crosses
/// the current rank boundary and falls back to the first incident endpoint.
fn select_vnode_anchor_neighbor(
  neighbors : Array[String],
  ranks : Map[String, Int],
  vnode_rank : Int,
  select_lower : Bool,
) -> String {
  for candidate in neighbors {
    let candidate_rank =
      match ranks.get(candidate) {
        Some(value) => value
        None => if select_lower { vnode_rank - 1 } else { vnode_rank + 1 }
      }
    if select_lower {
      if candidate_rank < vnode_rank {
        return candidate
      }
    } else if candidate_rank > vnode_rank {
      return candidate
    }
  }
  if neighbors.length() > 0 { neighbors[0] } else { "" }
}

///|
/// Graphviz parity: cluster-local ND_order seeds vnode positions by
/// interpolating between current tail/head orders inside the cluster.
/// Do not change behavior without updating fixtures/tests.
fn seed_local_groups_by_vnode(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let order_index : Map[String, Int] = Map::new()
  for rank in cluster_rank_keys {
    let names = match cluster_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for idx, name in names {
      order_index[name] = idx
    }
  }
  let seeded : Map[Int, Array[String]] = Map::new()
  for rank in cluster_rank_keys {
    let names = match cluster_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() <= 1 {
      if names.length() > 0 {
        seeded[rank] = names.copy()
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    for idx, name in names {
      let base_order = match order_index.get(name) {
        Some(value) => value
        None => idx
      }
      let mut key = Double::from_int(base_order)
      if is_edge_vnode_name(name) {
        let vnode_rank = match ranks.get(name) {
          Some(value) => value
          None => rank
        }
        let parent_name =
          match parents.get(name) {
            Some(list) =>
              select_vnode_anchor_neighbor(
                list,
                ranks,
                vnode_rank,
                true,
              )
            None => ""
          }
        let child_name =
          match children.get(name) {
            Some(list) =>
              select_vnode_anchor_neighbor(
                list,
                ranks,
                vnode_rank,
                false,
              )
            None => ""
          }
        if parent_name != "" && child_name != "" {
          let parent_rank = match ranks.get(parent_name) {
            Some(value) => value
            None => vnode_rank - 1
          }
          let child_rank = match ranks.get(child_name) {
            Some(value) => value
            None => vnode_rank + 1
          }
          let parent_order = match order_index.get(parent_name) {
            Some(value) => value
            None => base_order
          }
          let child_order = match order_index.get(child_name) {
            Some(value) => value
            None => base_order
          }
          let (low_rank, high_rank, low_order, high_order) =
            if parent_rank <= child_rank {
              (parent_rank, child_rank, parent_order, child_order)
            } else {
              (child_rank, parent_rank, child_order, parent_order)
            }
          let span = high_rank - low_rank
          if span > 0 {
            let t = Double::from_int(vnode_rank - low_rank) / Double::from_int(span)
            if low_order == high_order {
              key = Double::from_int(low_order) - (1.0 - t)
            } else {
              key =
                Double::from_int(low_order) +
                Double::from_int(high_order - low_order) * t
            }
          }
        }
      }
      items.push((key, idx, name))
    }
    items.sort_by((a, b) => {
      let (a_key, a_idx, _a_name) = a
      let (b_key, b_idx, _b_name) = b
      let diff = a_key - b_key
      if diff < -0.000000001 {
        -1
      } else if diff > 0.000000001 {
        1
      } else if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
    let reordered : Array[String] = []
    for item in items {
      let (_key, _idx, name) = item
      reordered.push(name)
    }
    seeded[rank] = reordered
  }
  seeded
}

///|
/// Graphviz parity: cluster-local reorder run-input payload keeps edge arrays
/// and metadata maps grouped for dispatch into reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderRunInputsOutput {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  edge_order : Map[String, Int]
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: cluster-local reorder builds internal edge bundle and
/// metadata maps from the same filtered cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_local_reorder_inputs(
  cluster_name : String,
  cluster_graph_edge_count : Int,
  expanded_clusters : Map[String, Bool],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  raw_graphviz_out_neighbors : Map[String, Array[String]],
  raw_graphviz_in_neighbors : Map[String, Array[String]],
  cluster_node_set : Map[String, Bool],
  cluster_rank_keys : Array[Int],
  cluster_nodes : Array[String],
  fixed_ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  intercluster_keys : Map[String, String],
  flat_constraints : Map[String, Bool],
) -> ClusterLocalReorderRunInputsOutput {
  let mut vnode_count = 0
  for name in cluster_nodes {
    if is_edge_vnode_name(name) {
      vnode_count = vnode_count + 1
    }
  }
  let include_external_crossing =
    if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
      cluster_rank_keys.length() <= 2
    } else if cluster_rank_keys.length() > 2 &&
      cluster_graph_edge_count == 0 &&
      vnode_count == 0 {
      false
    } else {
      true
    }
  let (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    edge_order,
  ) =
    {
      // Graphviz parity: shallow cluster-local reorder (<=2 ranks) needs both
      // incoming and outgoing crossing edges so median anchors see external slots.
      let cluster_edges : Array[@cgraph.Edge] = []
      let cluster_edge_tail : Array[String] = []
      let cluster_edge_head : Array[String] = []
      let cluster_edge_tail_port_x : Array[Double] = []
      let cluster_edge_head_port_x : Array[Double] = []
      let cluster_edge_tail_port_order : Array[Double] = []
      let cluster_edge_head_port_order : Array[Double] = []
      for i in 0..<order_edges.length() {
        let tail = order_edge_tail[i]
        let head = order_edge_head[i]
        let tail_in = cluster_node_set.get(tail) is Some(_)
        let head_in = cluster_node_set.get(head) is Some(_)
        let keep = (tail_in && head_in) ||
          (include_external_crossing && (tail_in || head_in))
        if !keep {
          continue
        }
        cluster_edges.push(order_edges[i])
        cluster_edge_tail.push(tail)
        cluster_edge_head.push(head)
        cluster_edge_tail_port_x.push(order_edge_tail_port_x[i])
        cluster_edge_head_port_x.push(order_edge_head_port_x[i])
        cluster_edge_tail_port_order.push(order_edge_tail_port_order[i])
        cluster_edge_head_port_order.push(order_edge_head_port_order[i])
      }
      let (parents, children) = build_edge_index_for_names(
        cluster_nodes,
        cluster_edge_tail,
        cluster_edge_head,
        fixed_ranks,
      )
      let edge_order = collect_edge_order(cluster_edges)
      (
        cluster_edges,
        cluster_edge_tail,
        cluster_edge_head,
        cluster_edge_tail_port_x,
        cluster_edge_head_port_x,
        cluster_edge_tail_port_order,
        cluster_edge_head_port_order,
        parents,
        children,
        edge_order,
      )
    }
  // Graphviz parity: cluster-local reorder metadata keeps node sizes,
  // local cluster keys, and same-rank flat constraints scoped to the cluster.
  let cluster_sizes : Map[String, NodeSize] = Map::new()
  for name, _ in cluster_node_set {
    match order_sizes.get(name) {
      Some(size) => cluster_sizes[name] = size
      None =>
        match vnode_sizes.get(name) {
          Some(size) => cluster_sizes[name] = size
          None => ()
        }
    }
  }
  let cluster_keys : Map[String, String] = Map::new()
  for name, _ in cluster_node_set {
    // Graphviz parity: mincross_clust() runs on the expanded subgraph where
    // ND_clust is cleared, so local reorder/transpose should not see
    // cross-cluster barriers for these nodes.
    cluster_keys[name] = ""
  }
  let cluster_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if cluster_node_set.get(tail) is Some(_) &&
          cluster_node_set.get(head) is Some(_) {
          cluster_flat_constraints[key] = value
        }
      }
      None => ()
    }
  }
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_local_neighbor_maps(
      cluster_name,
      expanded_clusters,
      cluster_nodes,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      raw_graphviz_out_neighbors,
      raw_graphviz_in_neighbors,
      intercluster_keys,
      cluster_edges.length() >= 5,
    )
  {
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    edge_order,
    cluster_sizes,
    cluster_keys,
    cluster_flat_constraints,
  }
}

///|
/// Graphviz parity: each cluster-local reorder pass reuses global fixed slots,
/// but only mutates rank entries that belong to that cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_group(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  raw_graphviz_out_neighbors : Map[String, Array[String]],
  raw_graphviz_in_neighbors : Map[String, Array[String]],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  empty_cluster_skeleton : Map[String, Bool],
  order_with_vnodes : Bool,
) -> Unit {
  // Graphviz parity: cluster-local reorder only considers nodes that are
  // present in rank groups and belong to the current cluster (plus local
  // virtual nodes when enabled).
  let cluster_nodes_set : Map[String, Bool] = Map::new()
  for node in cluster_graph.nodes() {
    cluster_nodes_set[node.name()] = true
  }
  if order_with_vnodes {
    for vnode, vnode_cluster in vnode_info.vnode_clusters {
      if vnode_cluster == cluster {
        cluster_nodes_set[vnode] = true
      }
    }
  }
  let cluster_node_set : Map[String, Bool] = Map::new()
  for _rank, names in groups {
    for name in names {
      if cluster_nodes_set.get(name) is Some(_) {
        cluster_node_set[name] = true
      }
    }
  }
  if cluster_node_set.length() <= 1 {
    return ()
  }
  // Graphviz parity: cluster-local node set uses global node_order as stable
  // seed to create deterministic local node indices.
  let cluster_nodes : Array[String] = []
  for name, _ in cluster_node_set {
    cluster_nodes.push(name)
  }
  let cluster_node_order : Map[String, Int] = Map::new()
  let cluster_ordered_nodes = cluster_nodes.copy()
  if cluster_ordered_nodes.length() > 1 {
    cluster_ordered_nodes.sort_by((a, b) => {
      compare_by_order_then_name(node_order, a, b)
    })
  }
  let mut order_idx = 0
  for name in cluster_ordered_nodes {
    cluster_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  let cluster_groups = build_local_rank_groups(
    groups,
    cluster_node_set,
    cluster_node_order,
    graphviz_out_neighbors,
  )
  let cluster_rank_keys = collect_rank_keys(cluster_groups)
  let cluster_fixed_positions : Map[String, Double] = Map::new()
  for name, value in fixed_positions {
    if cluster_node_set.get(name) is None {
      cluster_fixed_positions[name] = value
    }
  }
  let input_phase_output =
    build_local_reorder_inputs(
      cluster,
      cluster_graph.edges().length(),
      expanded_clusters,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      raw_graphviz_out_neighbors,
      raw_graphviz_in_neighbors,
      cluster_node_set,
      cluster_rank_keys,
      cluster_nodes,
      fixed_ranks,
      order_sizes,
      vnode_info.vnode_sizes,
      cluster_meta.intercluster_keys,
      cluster_meta.flat_constraints,
    )
  let (has_internal_constraints, ordered_cluster) =
    run_cluster_rank_reorder(
      cluster_rank_keys,
      cluster_groups,
      input_phase_output.cluster_edges,
      input_phase_output.cluster_edge_tail,
      input_phase_output.cluster_edge_head,
      input_phase_output.cluster_edge_tail_port_x,
      input_phase_output.cluster_edge_head_port_x,
      input_phase_output.cluster_edge_tail_port_order,
      input_phase_output.cluster_edge_head_port_order,
      input_phase_output.parents,
      input_phase_output.children,
      input_phase_output.graphviz_out_neighbors,
      input_phase_output.graphviz_in_neighbors,
      input_phase_output.cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      input_phase_output.edge_order,
      cluster_node_order,
      input_phase_output.cluster_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      empty_cluster_skeleton,
      input_phase_output.cluster_flat_constraints,
      cluster_fixed_positions,
      fixed_ranks,
    )
  if !has_internal_constraints {
    return ()
  }
  // Graphviz parity: cluster-local reorder writes only cluster members back to
  // existing rank slots, preserving non-cluster node positions.
  for rank in cluster_rank_keys {
    let desired = match ordered_cluster.get(rank) {
      Some(list) => list
      None => []
    }
    if desired.length() <= 1 {
      continue
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => continue
    }
    let mut idx = 0
    let mut pos = 0
    while pos < names.length() && idx < desired.length() {
      if cluster_node_set.get(names[pos]) is Some(_) {
        names[pos] = desired[idx]
        idx = idx + 1
      }
      pos = pos + 1
    }
  }
}

///|
/// Graphviz parity: cluster-local reorder iterates clusters in deterministic
/// build order and applies one independent local pass per cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_groups(
  cluster_names : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  raw_graphviz_out_neighbors : Map[String, Array[String]],
  raw_graphviz_in_neighbors : Map[String, Array[String]],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  empty_cluster_skeleton : Map[String, Bool],
  order_with_vnodes : Bool,
) -> Unit {
  let expanded_clusters : Map[String, Bool] = Map::new()
  let mut current_fixed_positions = fixed_positions
  for cluster in cluster_names {
    let cluster_graph = match cluster_graphs.get(cluster) {
      Some(value) => value
      None => continue
    }
    reorder_cluster_rank_group(
      cluster,
      expanded_clusters,
      cluster_graph,
      groups,
      node_order,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      raw_graphviz_out_neighbors,
      raw_graphviz_in_neighbors,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      cluster_meta,
      vnode_info,
      current_fixed_positions,
      fixed_ranks,
      empty_cluster_skeleton,
      order_with_vnodes,
    )
    expanded_clusters[cluster] = true
    current_fixed_positions = order_positions_from_groups(groups)
  }
}


///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
fn reorder_by_cluster_ranks(
  graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  order_with_vnodes : Bool,
) -> Unit {
  if cluster_meta.cluster_order.length() == 0 {
    return ()
  }
  let (cluster_graphs, cluster_names) =
    build_cluster_graph_order(
      graph,
      cluster_meta.cluster_order,
      cluster_meta.cluster_parents,
    )
  if cluster_graphs.length() == 0 {
    return ()
  }
  let empty_cluster_skeleton : Map[String, Bool] = Map::new()
  let fixed_positions = order_positions_from_groups(groups)
  let fixed_ranks : Map[String, Int] = Map::new()
  for name, rank in ranks {
    fixed_ranks[name] = rank
  }
  for name, rank in vnode_info.vnode_ranks {
    fixed_ranks[name] = rank
  }
  // Graphviz parity: cluster-local ND_out/ND_in maps keep raw graph
  // tail/head AGSEQ replay order for startpass=2 median anchors.
  let raw_graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let raw_graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for node in graph.nodes() {
    let name = node.name()
    raw_graphviz_out_neighbors[name] = []
    raw_graphviz_in_neighbors[name] = []
  }
  for edge in graph.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    match raw_graphviz_out_neighbors.get(tail) {
      Some(list) => list.push(head)
      None => raw_graphviz_out_neighbors[tail] = [head]
    }
    match raw_graphviz_in_neighbors.get(head) {
      Some(list) => list.push(tail)
      None => raw_graphviz_in_neighbors[head] = [tail]
    }
  }
  reorder_cluster_rank_groups(
    cluster_names,
    cluster_graphs,
    groups,
    node_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    raw_graphviz_out_neighbors,
    raw_graphviz_in_neighbors,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_meta,
    vnode_info,
    fixed_positions,
    fixed_ranks,
    empty_cluster_skeleton,
    order_with_vnodes,
  )
}
